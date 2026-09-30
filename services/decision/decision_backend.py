"""Reference implementation of the GDE-Nino AI decision layer backends.

This module implements the pluggable ``DecisionBackend`` described in
``docs/08-ai-decision-layer-jev.md`` (spine decisions D16-D18):

* one request shape for every backend: the TypeSafe System One
  ``POST /v1/systemone`` body ``{"model", "state", "questions"}``;
* four backends behind one protocol:
  (a) ``TypeSafeHTTPBackend``      - TypeSafe direct (Jev, pinned ``jev-1.13.0``);
  (b) ``gateway_backend``          - the same wire format through a gateway (OpenRouter);
  (c) ``SystemOneAdapterGeminiBackend`` - the official System One Adapter running on Gemini
      (placeholder; Agent Platform/Vertex project mode is unverified);
  (d) ``OpenWeightHTTPBackend``    - an open-weight, wire-compatible server (e.g. Von) on Cloud Run;
* ``FailoverBackend`` with a circuit breaker and a data-class guard (privacy rule R13);
* the threshold policy (Noul <0.30 no / 0.30-0.70 review / >0.70 yes; Choice abstains when the
  top probability is below 0.60; Score routes to the nearest level and asks for review when
  confidence is low);
* template rendering for ``schemas/decisions/*.json`` (the ``x-ectwin`` block is stripped);
* a row builder for the BigQuery ``decision_log`` table (``docs/03-architecture.md`` section 5.4).

Only ``httpx`` is required at import time. ``google-auth`` and ``system-one-adapter`` are imported
lazily by the code paths that need them.

Licence: Apache-2.0 (D20).
"""

from __future__ import annotations

import copy
import dataclasses
import hashlib
import json
import logging
import random
import re
import threading
import time
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import (
    Any,
    Callable,
    Iterable,
    Literal,
    Mapping,
    Protocol,
    Sequence,
    runtime_checkable,
)

import httpx

LOGGER = logging.getLogger("ectwin.decision")

QuestionType = Literal["noul", "choice", "score"]
DataClass = Literal["C0", "C1", "C2", "C3", "C4"]

DEFAULT_MODEL = "jev-1.13.0"
TYPESAFE_BASE_URL = "https://api.typesafe.ai"
SYSTEMONE_PATH = "/v1/systemone"
TEMPLATE_META_KEY = "x-ectwin"

MAX_CHOICE_OPTIONS = 255
MIN_SCORE_LEVELS = 2
MAX_SCORE_LEVELS = 10

# 408 timeout, 429 rate limit, every 5xx server error including 529 overloaded (TypeSafe);
# the same set as the SDK RetryPolicy default (408/429/500-599).
RETRYABLE_STATUS: frozenset[int] = frozenset({408, 429, *range(500, 600)})

# Which data classes each backend may receive (docs/08 section 10.2).
#   C0 public, C1 internal non-personal, C2 pseudonymised personal text,
#   C3 pseudonymised operational narratives (ECU 911 / SNGR), C4 never sent to any model.
DEFAULT_ACCEPTED_CLASSES: dict[str, frozenset[str]] = {
    "typesafe": frozenset({"C0", "C1", "C2"}),  # add C3 only after ZDR + DPA review
    "openrouter": frozenset({"C0", "C1"}),  # an extra intermediary: public/internal data only
    "gemini_adapter": frozenset({"C0", "C1", "C2"}),  # add C3 once Agent Platform mode is confirmed
    "open_weight": frozenset({"C0", "C1", "C2", "C3"}),  # runs inside our own GCP project
}


# --------------------------------------------------------------------------------------
# Errors
# --------------------------------------------------------------------------------------


class DecisionBackendError(Exception):
    """Base error of the decision layer."""


class TemplateError(DecisionBackendError):
    """A template could not be rendered (missing placeholder, bad structure)."""


class DecisionValidationError(DecisionBackendError):
    """The request or response is invalid (HTTP 4xx other than 408/429, or bad answers).

    ``retryable_elsewhere`` is True when another backend may accept the same request,
    for example when an open-weight server refuses a state that exceeds its context window.
    """

    def __init__(self, message: str, *, status: int | None = None, retryable_elsewhere: bool = False):
        super().__init__(message)
        self.status = status
        self.retryable_elsewhere = retryable_elsewhere


class BackendUnavailableError(DecisionBackendError):
    """Transient failure: timeout, connection error, 5xx or 529 after retries."""


class RateLimitedError(BackendUnavailableError):
    """HTTP 429 after retries."""

    def __init__(self, message: str, *, retry_after_s: float | None = None):
        super().__init__(message)
        self.retry_after_s = retry_after_s


class DataClassNotAllowedError(DecisionBackendError):
    """No configured backend may receive the request's data class."""


# --------------------------------------------------------------------------------------
# Request / response types
# --------------------------------------------------------------------------------------


@dataclass(frozen=True)
class DecisionRequest:
    """A typed decision request in the ``/v1/systemone`` shape plus routing metadata."""

    state: Any
    questions: Mapping[str, Mapping[str, Any]]
    model: str = DEFAULT_MODEL
    template_id: str | None = None
    template_version: str | None = None
    context: str = "triage"
    data_class: DataClass = "C1"

    def to_body(self) -> dict[str, Any]:
        """Return the exact JSON body sent to a ``/v1/systemone`` endpoint."""
        return {
            "model": self.model,
            "state": copy.deepcopy(self.state),
            "questions": {qid: dict(q) for qid, q in self.questions.items()},
        }

    def subset(self, question_ids: Iterable[str]) -> "DecisionRequest":
        """Return a copy restricted to ``question_ids`` (used for two-stage templates such as S1)."""
        wanted = list(question_ids)
        missing = [qid for qid in wanted if qid not in self.questions]
        if missing:
            raise TemplateError(f"unknown question ids: {missing}")
        return DecisionRequest(
            state=self.state,
            questions={qid: self.questions[qid] for qid in wanted},
            model=self.model,
            template_id=self.template_id,
            template_version=self.template_version,
            context=self.context,
            data_class=self.data_class,
        )


@dataclass(frozen=True)
class Answer:
    """One answer as returned by a System One compatible backend."""

    question_id: str
    type: QuestionType
    noul: float | None = None
    choice: str | None = None
    score: float | None = None
    confidence: float | None = None
    probabilities: dict[str, float] = field(default_factory=dict)
    legend: dict[str, str] = field(default_factory=dict)

    def raw(self) -> dict[str, Any]:
        """Raw probabilities as they should be logged (no policy applied)."""
        if self.type == "noul":
            return {"noul": self.noul}
        out: dict[str, Any] = {"probabilities": dict(self.probabilities), "confidence": self.confidence}
        if self.type == "choice":
            out["choice"] = self.choice
        else:
            out["score"] = self.score
            out["legend"] = dict(self.legend)
        return out


@dataclass(frozen=True)
class DecisionResponse:
    backend: str
    model: str
    answers: dict[str, Answer]
    input_tokens: int | None
    output_tokens: int | None
    latency_ms: int
    request_sha256: str
    request_id: str
    truncated: bool = False
    fallback_from: tuple[str, ...] = ()


# --------------------------------------------------------------------------------------
# Hashing, validation and parsing
# --------------------------------------------------------------------------------------


def canonical_json(obj: Any) -> str:
    """Deterministic JSON used for hashing and caching."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def request_sha256(body: Mapping[str, Any]) -> str:
    """SHA-256 of the canonical (pseudonymised) request body; the cache and idempotency key."""
    return hashlib.sha256(canonical_json(body).encode("utf-8")).hexdigest()


def validate_request(request: DecisionRequest) -> None:
    """Check the documented System One limits before any network call."""
    if not request.questions:
        raise DecisionValidationError("request has no questions")
    for qid, q in request.questions.items():
        qtype = q.get("type")
        if qtype not in ("noul", "choice", "score"):
            raise DecisionValidationError(f"{qid}: unknown question type {qtype!r}")
        if not q.get("instructions"):
            raise DecisionValidationError(f"{qid}: instructions are required (question ids are never sent to the model)")
        criteria = q.get("criteria")
        if qtype == "choice":
            if not isinstance(criteria, Mapping) or not criteria:
                raise DecisionValidationError(f"{qid}: choice criteria must be a non-empty map")
            if len(criteria) > MAX_CHOICE_OPTIONS:
                raise DecisionValidationError(f"{qid}: {len(criteria)} options exceed {MAX_CHOICE_OPTIONS}")
        elif qtype == "score":
            if not isinstance(criteria, Sequence) or isinstance(criteria, (str, bytes)):
                raise DecisionValidationError(f"{qid}: score criteria must be an ordered list")
            if not MIN_SCORE_LEVELS <= len(criteria) <= MAX_SCORE_LEVELS:
                raise DecisionValidationError(f"{qid}: score needs 2-10 levels, got {len(criteria)}")
        elif criteria is not None and not isinstance(criteria, Mapping):
            raise DecisionValidationError(f"{qid}: noul criteria must be a map with 'true'/'false'")


def _prob(value: Any, where: str) -> float:
    try:
        p = float(value)
    except (TypeError, ValueError) as exc:
        raise DecisionValidationError(f"{where}: not a number: {value!r}") from exc
    if not 0.0 <= p <= 1.0:
        raise DecisionValidationError(f"{where}: probability out of range: {p}")
    return p


def parse_answers(raw_answers: Mapping[str, Any], request: DecisionRequest | None = None) -> dict[str, Answer]:
    """Parse the ``answers`` object of a ``/v1/systemone`` response and check it against the request."""
    answers: dict[str, Answer] = {}
    for qid, a in raw_answers.items():
        if not isinstance(a, Mapping):
            raise DecisionValidationError(f"{qid}: answer is not an object")
        qtype = a.get("type")
        if request is not None and qid in request.questions:
            qtype = qtype or request.questions[qid].get("type")
        if qtype == "noul":
            answers[qid] = Answer(qid, "noul", noul=_prob(a.get("noul"), qid))
        elif qtype == "choice":
            probs = {str(k): _prob(v, f"{qid}.{k}") for k, v in (a.get("probabilities") or {}).items()}
            choice = a.get("choice")
            if choice is None and probs:
                choice = max(probs, key=probs.__getitem__)
            conf = a.get("confidence")
            answers[qid] = Answer(
                qid, "choice", choice=str(choice), probabilities=probs,
                confidence=None if conf is None else _prob(conf, f"{qid}.confidence"),
            )
        elif qtype == "score":
            probs = {str(k): _prob(v, f"{qid}.{k}") for k, v in (a.get("probabilities") or {}).items()}
            conf = a.get("confidence")
            answers[qid] = Answer(
                qid, "score", score=float(a.get("score", 0.0)), probabilities=probs,
                confidence=None if conf is None else _prob(conf, f"{qid}.confidence"),
                legend={str(k): str(v) for k, v in (a.get("legend") or {}).items()},
            )
        else:
            raise DecisionValidationError(f"{qid}: unknown answer type {qtype!r}")
    if request is not None:
        missing = sorted(set(request.questions) - set(answers))
        if missing:
            raise DecisionValidationError(f"answers missing for {missing}")
    return answers


# --------------------------------------------------------------------------------------
# Protocol
# --------------------------------------------------------------------------------------


@runtime_checkable
class DecisionBackend(Protocol):
    """Anything that answers a ``/v1/systemone`` request."""

    name: str
    accepted_data_classes: frozenset[str]

    def decide(self, request: DecisionRequest) -> DecisionResponse:
        """Answer every question of ``request`` in one call."""
        ...

    def close(self) -> None:
        """Release network resources."""
        ...


# --------------------------------------------------------------------------------------
# HTTP backends (a), (b), (d)
# --------------------------------------------------------------------------------------


def _parse_retry_after(value: str | None) -> float | None:
    if not value:
        return None
    try:
        return max(0.0, float(value))
    except ValueError:
        return None  # HTTP-date form: fall back to exponential backoff


class SystemOneHTTPBackend:
    """Shared HTTP client for any ``/v1/systemone`` compatible endpoint.

    * one long-lived ``httpx.Client`` per backend instance (thread-safe);
    * at most ``max_concurrency`` requests in flight (about 8 workers per key is the
      documented safe level for TypeSafe);
    * retries on 408/429/5xx/529 with exponential backoff and jitter, honouring ``retry-after``.
    """

    def __init__(
        self,
        name: str,
        base_url: str,
        *,
        api_key: str | None = None,
        token_provider: Callable[[], str] | None = None,
        model_override: str | None = None,
        timeout_s: float = 10.0,
        max_retries: int = 2,
        backoff_initial_s: float = 0.5,
        backoff_max_s: float = 5.0,
        max_concurrency: int = 8,
        accepted_data_classes: frozenset[str] | None = None,
        extra_headers: Mapping[str, str] | None = None,
        client: httpx.Client | None = None,
    ) -> None:
        if api_key is not None and (not api_key.strip() or api_key != api_key.strip()):
            raise ValueError("api_key is empty or has surrounding whitespace")
        self.name = name
        self.accepted_data_classes = accepted_data_classes or DEFAULT_ACCEPTED_CLASSES.get(name, frozenset({"C0", "C1"}))
        self._api_key = api_key
        self._token_provider = token_provider
        self._model_override = model_override
        self._max_retries = max_retries
        self._backoff_initial_s = backoff_initial_s
        self._backoff_max_s = backoff_max_s
        self._slots = threading.BoundedSemaphore(max_concurrency)
        self._extra_headers = dict(extra_headers or {})
        self._client = client or httpx.Client(base_url=base_url, timeout=timeout_s)

    # -- hooks -------------------------------------------------------------------------

    def _headers(self) -> dict[str, str]:
        headers = {"Content-Type": "application/json", **self._extra_headers}
        token = self._token_provider() if self._token_provider else self._api_key
        if token:
            headers["Authorization"] = f"Bearer {token}"
        return headers

    def _is_truncated(self, response: httpx.Response, data: Mapping[str, Any]) -> bool:
        return False

    def _classify_client_error(self, response: httpx.Response) -> DecisionValidationError:
        return DecisionValidationError(
            f"{self.name}: HTTP {response.status_code}: {response.text[:500]}", status=response.status_code
        )

    # -- main call ---------------------------------------------------------------------

    def decide(self, request: DecisionRequest) -> DecisionResponse:
        validate_request(request)
        body = request.to_body()
        if self._model_override:
            body["model"] = self._model_override
        sha = request_sha256(body)
        started = time.monotonic()
        last_error: Exception | None = None
        with self._slots:
            for attempt in range(self._max_retries + 1):
                try:
                    response = self._client.post(SYSTEMONE_PATH, json=body, headers=self._headers())
                except (httpx.TimeoutException, httpx.TransportError) as exc:
                    last_error = exc
                    if attempt < self._max_retries:
                        self._sleep(attempt, None)
                        continue
                    raise BackendUnavailableError(f"{self.name}: {type(exc).__name__}: {exc}") from exc

                status = response.status_code
                if status in RETRYABLE_STATUS:
                    retry_after = _parse_retry_after(response.headers.get("retry-after"))
                    if attempt < self._max_retries:
                        self._sleep(attempt, retry_after)
                        continue
                    if status == 429:
                        raise RateLimitedError(f"{self.name}: HTTP 429 after retries", retry_after_s=retry_after)
                    raise BackendUnavailableError(f"{self.name}: HTTP {status} after retries")
                if 400 <= status < 500:
                    raise self._classify_client_error(response)
                if status >= 300:
                    raise BackendUnavailableError(f"{self.name}: unexpected HTTP {status}")

                try:
                    data = response.json()
                except ValueError as exc:
                    raise BackendUnavailableError(f"{self.name}: response is not JSON") from exc
                answers = parse_answers(data.get("answers") or {}, request)
                usage = data.get("usage") or {}
                return DecisionResponse(
                    backend=self.name,
                    model=str(data.get("model") or body["model"]),
                    answers=answers,
                    input_tokens=usage.get("input_tokens"),
                    output_tokens=usage.get("output_tokens"),
                    latency_ms=int((time.monotonic() - started) * 1000),
                    request_sha256=sha,
                    request_id=str(response.headers.get("x-request-id") or uuid.uuid4()),
                    truncated=self._is_truncated(response, data),
                )
        raise BackendUnavailableError(f"{self.name}: exhausted retries: {last_error}")  # pragma: no cover

    def _sleep(self, attempt: int, retry_after_s: float | None) -> None:
        if retry_after_s is not None:
            delay = min(retry_after_s, 60.0)
        else:
            delay = min(self._backoff_max_s, self._backoff_initial_s * (2**attempt))
            delay *= 1.0 + random.uniform(-0.25, 0.25)
        time.sleep(max(0.0, delay))

    def close(self) -> None:
        self._client.close()


class TypeSafeHTTPBackend(SystemOneHTTPBackend):
    """(a) TypeSafe direct. The key comes from Secret Manager (Commons or tenant), never from code."""

    def __init__(self, api_key: str, *, base_url: str = TYPESAFE_BASE_URL, zdr_enabled: bool = False, **kwargs: Any) -> None:
        classes = set(DEFAULT_ACCEPTED_CLASSES["typesafe"])
        if zdr_enabled:  # only after enterprise zero-data-retention terms and the DPA review (docs/08 section 10)
            classes.add("C3")
        kwargs.setdefault("accepted_data_classes", frozenset(classes))
        super().__init__("typesafe", base_url, api_key=api_key, **kwargs)


def gateway_backend(api_key: str, *, base_url: str = "https://openrouter.ai/api", model: str = "~typesafe/jev-latest",
                    **kwargs: Any) -> SystemOneHTTPBackend:
    """(b) Jev through a gateway (OpenRouter shown). Whether a pinned version id is routable
    through the gateway is to be confirmed; until then the gateway uses the alias and every
    answer's ``model`` field is logged so a silent model change is detectable."""
    return SystemOneHTTPBackend("openrouter", base_url, api_key=api_key, model_override=model, **kwargs)


class OpenWeightHTTPBackend(SystemOneHTTPBackend):
    """(d) Open-weight, wire-compatible server (e.g. Von) on Cloud Run in our own project.

    Deploy the server with ``VON_ON_OVERFLOW=refuse`` so an oversize state returns HTTP 422
    instead of being silently middle-truncated; if truncation is allowed, the response is
    marked ``truncated`` and the policy forces human review.
    """

    def __init__(self, base_url: str, *, use_google_id_token: bool = True, api_key: str | None = None,
                 **kwargs: Any) -> None:
        provider = google_id_token_provider(base_url) if use_google_id_token and api_key is None else None
        kwargs.setdefault("timeout_s", 30.0)
        super().__init__("open_weight", base_url, api_key=api_key, token_provider=provider, **kwargs)

    def _is_truncated(self, response: httpx.Response, data: Mapping[str, Any]) -> bool:
        return bool(data.get("truncation")) or response.headers.get("x-von-truncated", "").lower() in ("1", "true")

    def _classify_client_error(self, response: httpx.Response) -> DecisionValidationError:
        text = response.text[:500]
        overflow = response.status_code == 422 and "context window" in text.lower()
        return DecisionValidationError(
            f"{self.name}: HTTP {response.status_code}: {text}", status=response.status_code, retryable_elsewhere=overflow
        )


def google_id_token_provider(audience: str, refresh_after_s: float = 45 * 60) -> Callable[[], str]:
    """Return a cached Google-signed ID token for a private Cloud Run service (IAM invoker)."""
    cache: dict[str, Any] = {"token": None, "at": 0.0}
    lock = threading.Lock()

    def _get() -> str:
        with lock:
            if cache["token"] is None or time.monotonic() - cache["at"] > refresh_after_s:
                import google.auth.transport.requests  # lazy: only needed on Cloud Run
                import google.oauth2.id_token

                cache["token"] = google.oauth2.id_token.fetch_id_token(
                    google.auth.transport.requests.Request(), audience
                )
                cache["at"] = time.monotonic()
            return str(cache["token"])

    return _get


# --------------------------------------------------------------------------------------
# (c) System One Adapter on Gemini - placeholder
# --------------------------------------------------------------------------------------


class SystemOneAdapterGeminiBackend:
    """(c) Runs the same request on Gemini through the official System One Adapter
    (``pip install 'system-one-adapter[gemini]'``), so spend lands on a Google invoice.

    PLACEHOLDER - to confirm before production:
      * the adapter documents the Gemini Interactions API with ``GEMINI_API_KEY`` /
        ``GOOGLE_API_KEY`` or a Gemini client passed in; whether a client configured for the
        tenant's Agent Platform (formerly Vertex AI) project works is UNVERIFIED;
      * the exact Gemini model id string must be taken from the Agent Platform model list;
      * whether raw dict questions are accepted (as in ``typesafe-sdk``) must be tested.
    Until Agent Platform mode is confirmed this backend does not accept C3 data.
    """

    name = "gemini_adapter"

    def __init__(self, gemini_model: str | None = None, *, gemini_client: Any | None = None,
                 agent_platform_mode_confirmed: bool = False) -> None:
        if gemini_model is None and gemini_client is None:
            raise ValueError("pass gemini_model (id to confirm) or a configured Gemini client/provider")
        try:
            from system_one_adapter import SystemOneAdapterClient  # type: ignore[import-not-found]
        except ImportError as exc:  # pragma: no cover - optional dependency
            raise BackendUnavailableError("install 'system-one-adapter[gemini]' to use this backend") from exc
        self._client = SystemOneAdapterClient(
            structured_outputs=True, llm_answer_mode="probabilities", normalize_probabilities=True
        )
        self._gemini_model = gemini_model
        self._gemini_client = gemini_client
        classes = set(DEFAULT_ACCEPTED_CLASSES["gemini_adapter"])
        if agent_platform_mode_confirmed:
            classes.add("C3")
        self.accepted_data_classes = frozenset(classes)

    def decide(self, request: DecisionRequest) -> DecisionResponse:
        validate_request(request)
        body = request.to_body()
        started = time.monotonic()
        try:
            if self._gemini_client is not None:
                result = self._client.system_one(body["state"], body["questions"], model=self._gemini_client)
            else:
                result = self._client.system_one(
                    body["state"], body["questions"], provider="gemini", model=self._gemini_model
                )
            data = result.model_dump()
        except Exception as exc:  # the adapter raises TypeSafeError subclasses and provider errors
            raise BackendUnavailableError(f"gemini_adapter: {type(exc).__name__}: {exc}") from exc
        usage = data.get("usage") or {}
        return DecisionResponse(
            backend=self.name,
            model=f"gemini-adapter:{self._gemini_model or 'client'}",
            answers=parse_answers(data.get("answers") or {}, request),
            input_tokens=usage.get("input_tokens_total", usage.get("input_tokens")),
            output_tokens=usage.get("output_tokens_total", usage.get("output_tokens")),
            latency_ms=int((time.monotonic() - started) * 1000),
            request_sha256=request_sha256(body),
            request_id=str(uuid.uuid4()),
        )

    def close(self) -> None:
        closer = getattr(self._client, "close", None)
        if callable(closer):
            closer()


# --------------------------------------------------------------------------------------
# Failover with circuit breaker and data-class guard
# --------------------------------------------------------------------------------------


@dataclass
class CircuitBreaker:
    """Per-process breaker, aligned with runbook RB-09 (docs/11-operations-runbook.md):
    opens after ``failure_threshold`` consecutive failures; after ``cooldown_s`` (10 min) it
    half-opens and lets canary requests through; it closes after ``half_open_successes``
    consecutive canary successes and re-opens on any canary failure. The fleet-level trigger
    (error rate above 5% for 5 min, alert OPS-A13) is handled by Cloud Monitoring."""

    failure_threshold: int = 5
    cooldown_s: float = 600.0
    half_open_successes: int = 5
    failures: int = 0
    opened_at: float | None = None
    canary_ok: int = 0
    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    @property
    def state(self) -> str:
        if self.opened_at is None:
            return "closed"
        return "half_open" if time.monotonic() - self.opened_at >= self.cooldown_s else "open"

    def allow(self) -> bool:
        with self._lock:
            return self.state != "open"

    def record_success(self) -> None:
        with self._lock:
            if self.state == "half_open":
                self.canary_ok += 1
                if self.canary_ok < self.half_open_successes:
                    return
            self.failures = 0
            self.opened_at = None
            self.canary_ok = 0

    def record_failure(self) -> None:
        with self._lock:
            if self.state == "half_open":
                self.opened_at = time.monotonic()  # canary failed: open again for a full cooldown
                self.canary_ok = 0
                return
            self.failures += 1
            if self.failures >= self.failure_threshold:
                self.opened_at = time.monotonic()
                self.canary_ok = 0


class FailoverBackend:
    """Tries backends in order, skipping those whose breaker is open or that may not receive
    the request's data class. Every answer records which backends were skipped or failed.

    ``failover=False`` keeps only the primary backend: used for non-urgent templates
    (catalogue, PDF QA, place resolution, historical labelling, dedupe backfills), whose items
    are queued until the primary recovers instead of being answered by an uncalibrated fallback
    (runbook RB-09 step 4)."""

    name = "failover"

    def __init__(self, backends: Sequence[DecisionBackend], *, failure_threshold: int = 5,
                 cooldown_s: float = 600.0, half_open_successes: int = 5, failover: bool = True) -> None:
        if not backends:
            raise ValueError("at least one backend is required")
        self._backends = list(backends) if failover else list(backends)[:1]
        self._breakers = {
            b.name: CircuitBreaker(failure_threshold, cooldown_s, half_open_successes) for b in self._backends
        }
        self.accepted_data_classes = frozenset().union(*(b.accepted_data_classes for b in self._backends))

    def decide(self, request: DecisionRequest) -> DecisionResponse:
        if request.data_class == "C4":
            raise DataClassNotAllowedError("C4 data is never sent to any model")
        tried: list[str] = []
        last_error: Exception | None = None
        for backend in self._backends:
            if request.data_class not in backend.accepted_data_classes:
                tried.append(f"{backend.name}:data_class")
                continue
            breaker = self._breakers[backend.name]
            if not breaker.allow():
                tried.append(f"{backend.name}:circuit_open")
                continue
            try:
                response = backend.decide(request)
            except DecisionValidationError as exc:
                if not exc.retryable_elsewhere:
                    raise  # the request itself is wrong: do not spray it across backends
                tried.append(f"{backend.name}:{exc.status}")
                last_error = exc
                continue
            except BackendUnavailableError as exc:
                breaker.record_failure()
                tried.append(f"{backend.name}:unavailable")
                last_error = exc
                LOGGER.warning("decision backend %s failed: %s", backend.name, exc)
                continue
            breaker.record_success()
            if tried:
                response = dataclasses.replace(response, fallback_from=tuple(tried))
            return response
        if last_error is None:
            raise DataClassNotAllowedError(
                f"no backend accepts data class {request.data_class} (tried {tried})"
            )
        raise BackendUnavailableError(f"all decision backends failed: {tried}") from last_error

    def close(self) -> None:
        for backend in self._backends:
            backend.close()


# --------------------------------------------------------------------------------------
# Threshold policy (D16)
# --------------------------------------------------------------------------------------


@dataclass(frozen=True)
class ThresholdPolicy:
    """Noul <noul_low no / [noul_low, noul_high] review / >noul_high yes; Choice abstains below
    ``choice_abstain``; Score asks for review below ``score_confidence_min``."""

    noul_low: float = 0.30
    noul_high: float = 0.70
    choice_abstain: float = 0.60
    score_confidence_min: float = 0.50

    def __post_init__(self) -> None:
        if not 0.0 <= self.noul_low <= self.noul_high <= 1.0:
            raise ValueError("need 0 <= noul_low <= noul_high <= 1")

    def describe(self) -> str:
        """Policy string stored in ``decision_log.policy``."""
        return (f"noul:{self.noul_low:.2f}/{self.noul_high:.2f};choice_abstain:{self.choice_abstain:.2f};"
                f"score_conf:{self.score_confidence_min:.2f}")


DEFAULT_POLICY = ThresholdPolicy()

# Jev (direct or through a gateway) uses the spine policy. Fallback backends start on the wider
# runbook RB-09 bands (review 0.20-0.80, abstain below 0.70) because their probabilities are not
# calibrated like Jev's; replace per backend after the calibration study (docs/08 section 5.5).
# Stored probabilities let history be re-routed under a new policy without new model calls.
FALLBACK_POLICY = ThresholdPolicy(noul_low=0.20, noul_high=0.80, choice_abstain=0.70, score_confidence_min=0.50)

BACKEND_POLICIES: dict[str, ThresholdPolicy] = {
    "typesafe": DEFAULT_POLICY,
    "openrouter": DEFAULT_POLICY,
    "gemini_adapter": FALLBACK_POLICY,
    "open_weight": FALLBACK_POLICY,
}


@dataclass(frozen=True)
class PolicyDecision:
    question_id: str
    question_type: QuestionType
    outcome: str  # 'yes' | 'no' | 'review' | 'abstain' | '<choice label>' | 'level:<n>'
    needs_review: bool
    value: float | None
    detail: str = ""


def apply_noul(p: float, policy: ThresholdPolicy = DEFAULT_POLICY) -> str:
    """Three bands: below 0.30 'no', 0.30-0.70 inclusive 'review', above 0.70 'yes'."""
    if p < policy.noul_low:
        return "no"
    if p > policy.noul_high:
        return "yes"
    return "review"


def apply_choice(probabilities: Mapping[str, float], policy: ThresholdPolicy = DEFAULT_POLICY) -> tuple[str, float, float]:
    """Return (label or 'abstain', top probability, margin over the runner-up)."""
    if not probabilities:
        return "abstain", 0.0, 0.0
    ranked = sorted(probabilities.items(), key=lambda kv: kv[1], reverse=True)
    top_label, top_p = ranked[0]
    margin = top_p - (ranked[1][1] if len(ranked) > 1 else 0.0)
    if top_p < policy.choice_abstain or margin <= 0.0:
        return "abstain", top_p, margin
    return top_label, top_p, margin


def score_level(score: float, n_levels: int) -> int:
    """Nearest level: ``min(int(score + 0.5), n - 1)``."""
    return max(0, min(int(score + 0.5), n_levels - 1))


def apply_score(score: float, n_levels: int, confidence: float | None,
                policy: ThresholdPolicy = DEFAULT_POLICY) -> tuple[int, bool]:
    """Return (nearest level, needs_review)."""
    level = score_level(score, n_levels)
    needs_review = confidence is None or confidence < policy.score_confidence_min
    return level, needs_review


def evaluate(response: DecisionResponse, request: DecisionRequest,
             policy: ThresholdPolicy | None = None) -> dict[str, PolicyDecision]:
    """Apply the threshold policy to every answer. Truncated states always go to review."""
    pol = policy or BACKEND_POLICIES.get(response.backend, DEFAULT_POLICY)
    decisions: dict[str, PolicyDecision] = {}
    for qid, ans in response.answers.items():
        if ans.type == "noul":
            assert ans.noul is not None
            outcome = apply_noul(ans.noul, pol)
            decisions[qid] = PolicyDecision(qid, "noul", outcome, outcome == "review", ans.noul)
        elif ans.type == "choice":
            label, top_p, margin = apply_choice(ans.probabilities, pol)
            decisions[qid] = PolicyDecision(qid, "choice", label, label == "abstain", top_p,
                                            f"margin={margin:.2f}")
        else:
            criteria = request.questions.get(qid, {}).get("criteria") or []
            n_levels = len(criteria) if isinstance(criteria, Sequence) else len(ans.probabilities)
            level, review = apply_score(ans.score or 0.0, max(n_levels, 2), ans.confidence, pol)
            decisions[qid] = PolicyDecision(qid, "score", f"level:{level}", review, ans.score,
                                            f"confidence={ans.confidence}")
        if response.truncated and not decisions[qid].needs_review:
            d = decisions[qid]
            decisions[qid] = PolicyDecision(d.question_id, d.question_type, d.outcome, True, d.value,
                                            (d.detail + ";truncated_state").lstrip(";"))
    return decisions


def combine_flags_max(values: Iterable[float]) -> float:
    """'Something is wrong' flags combine with max (averaging hides one bad field)."""
    return max(values, default=0.0)


def combine_parts_min(values: Iterable[float]) -> float:
    """The parts one decision relies on combine with min."""
    return min(values, default=0.0)


def resolve_gate(hard_rule: bool | None, jev_outcome: str) -> str:
    """S4 model-run gate: code hard rules always win; Jev decides only when no rule applies.
    Returns 'run', 'skip' or 'review'."""
    if hard_rule is True:
        return "run"
    if hard_rule is False:
        return "skip"
    return {"yes": "run", "no": "skip"}.get(jev_outcome, "review")


def bucketise(value: float, edges: Sequence[float], labels: Sequence[str]) -> str:
    """Code keeps numbers: convert a value into a named bucket before it reaches Jev.
    ``edges`` are ascending upper bounds; ``labels`` has one more entry than ``edges``."""
    if len(labels) != len(edges) + 1:
        raise ValueError("labels must have len(edges) + 1 entries")
    for edge, label in zip(edges, labels):
        if value < edge:
            return label
    return labels[-1]


# --------------------------------------------------------------------------------------
# Templates (schemas/decisions/*.json)
# --------------------------------------------------------------------------------------

_FULL_PLACEHOLDER = re.compile(r"^\{\{\s*([A-Za-z0-9_]+)\s*\}\}$")
_INLINE_PLACEHOLDER = re.compile(r"\{\{\s*([A-Za-z0-9_]+)\s*\}\}")


def _substitute(node: Any, values: Mapping[str, Any], missing: set[str]) -> Any:
    if isinstance(node, str):
        full = _FULL_PLACEHOLDER.match(node)
        if full:
            key = full.group(1)
            if key not in values:
                missing.add(key)
                return node
            return copy.deepcopy(values[key])  # may be an object, array, string or number
        def _inline(m: re.Match[str]) -> str:
            key = m.group(1)
            if key not in values:
                missing.add(key)
                return m.group(0)
            return str(values[key])
        return _INLINE_PLACEHOLDER.sub(_inline, node)
    if isinstance(node, list):
        return [_substitute(item, values, missing) for item in node]
    if isinstance(node, dict):
        return {k: _substitute(v, values, missing) for k, v in node.items()}
    return node


def render_template(template: Path | str | Mapping[str, Any], values: Mapping[str, Any], *,
                    stage: str | None = None, model: str | None = None) -> tuple[DecisionRequest, dict[str, Any]]:
    """Render a ``schemas/decisions`` template into a ``DecisionRequest``.

    The ``x-ectwin`` block is removed from the body and returned as metadata; ``stage`` selects
    a question subset declared in ``x-ectwin.stages`` (e.g. the S1 'gate' stage).
    """
    if isinstance(template, Mapping):
        raw = copy.deepcopy(dict(template))
    else:
        raw = json.loads(Path(template).read_text(encoding="utf-8"))
    meta = raw.pop(TEMPLATE_META_KEY, {})
    missing: set[str] = set()
    rendered = _substitute(raw, values, missing)
    if missing:
        raise TemplateError(f"{meta.get('template_id')}: missing placeholder values: {sorted(missing)}")
    leftover = _INLINE_PLACEHOLDER.search(canonical_json(rendered))
    if leftover:
        raise TemplateError(f"unrendered placeholder {leftover.group(0)}")
    request = DecisionRequest(
        state=rendered.get("state"),
        questions=rendered.get("questions") or {},
        model=model or rendered.get("model") or DEFAULT_MODEL,
        template_id=meta.get("template_id"),
        template_version=meta.get("template_version"),
        context=meta.get("decision_log_context", "triage"),
        data_class=meta.get("data_class", "C1"),
    )
    if stage is not None:
        stage_ids = (meta.get("stages") or {}).get(stage)
        if not stage_ids:
            raise TemplateError(f"template has no stage {stage!r}")
        request = request.subset(stage_ids)
    validate_request(request)
    return request, meta


# --------------------------------------------------------------------------------------
# BigQuery decision_log rows (docs/03-architecture.md section 5.4)
# --------------------------------------------------------------------------------------

DECISION_LOG_COLUMNS: tuple[str, ...] = (
    "decision_id", "ts", "context", "actor_uid", "backend", "model_version", "question_type",
    "request_sha256", "probabilities", "policy", "outcome", "human_reviewer", "human_outcome",
    "related_run_key", "related_aoi_id", "dpa_code", "note",
)
# Additive columns proposed in docs/08 section 9.6 (ALTER TABLE ... ADD COLUMN).
DECISION_LOG_EXTENSION_COLUMNS: tuple[str, ...] = (
    "question_id", "template_id", "template_version", "request_id", "input_tokens", "latency_ms",
    "needs_review", "fallback_from",
)


def build_decision_log_rows(
    request: DecisionRequest,
    response: DecisionResponse,
    decisions: Mapping[str, PolicyDecision],
    *,
    policy: ThresholdPolicy | None = None,
    actor_uid: str | None = None,
    related_run_key: str | None = None,
    related_aoi_id: str | None = None,
    dpa_code: str | None = None,
    note: str | None = None,
    include_extensions: bool = True,
    ts: datetime | None = None,
) -> list[dict[str, Any]]:
    """One row per question, ready for ``insert_rows_json`` or a load job.

    ``probabilities`` holds the raw answer (JSON text) so thresholds can be changed later and
    history re-routed without calling any model again. ``input_tokens`` is per request and is
    repeated on each row: aggregate with ``COUNT(DISTINCT request_id)`` / ``ANY_VALUE``.
    """
    pol = policy or BACKEND_POLICIES.get(response.backend, DEFAULT_POLICY)
    when = (ts or datetime.now(timezone.utc)).astimezone(timezone.utc).isoformat()
    rows: list[dict[str, Any]] = []
    for qid, answer in response.answers.items():
        decision = decisions.get(qid)
        row: dict[str, Any] = {
            "decision_id": f"{response.request_id}/{qid}",
            "ts": when,
            "context": request.context,
            "actor_uid": actor_uid,
            "backend": response.backend,
            "model_version": response.model,
            "question_type": answer.type,
            "request_sha256": response.request_sha256,
            "probabilities": canonical_json(answer.raw()),
            "policy": pol.describe(),
            "outcome": decision.outcome if decision else None,
            "human_reviewer": None,
            "human_outcome": None,
            "related_run_key": related_run_key,
            "related_aoi_id": related_aoi_id,
            "dpa_code": dpa_code,
            "note": note,
        }
        if include_extensions:
            row.update({
                "question_id": qid,
                "template_id": request.template_id,
                "template_version": request.template_version,
                "request_id": response.request_id,
                "input_tokens": response.input_tokens,
                "latency_ms": response.latency_ms,
                "needs_review": decision.needs_review if decision else True,
                "fallback_from": list(response.fallback_from),
            })
        rows.append(row)
    return rows


def build_human_review_row(decision_id: str, *, reviewer_uid: str, human_outcome: str, context: str,
                           note: str | None = None, ts: datetime | None = None) -> dict[str, Any]:
    """Row recording a human confirmation or override of an earlier automated decision
    (a new row referencing ``decision_id`` in ``note``; logged rows are never updated)."""
    when = (ts or datetime.now(timezone.utc)).astimezone(timezone.utc).isoformat()
    return {
        "decision_id": f"{decision_id}#review#{uuid.uuid4().hex[:8]}",
        "ts": when,
        "context": context,
        "actor_uid": reviewer_uid,
        "backend": None,
        "model_version": None,
        "question_type": None,
        "request_sha256": None,
        "probabilities": None,
        "policy": None,
        "outcome": None,
        "human_reviewer": reviewer_uid,
        "human_outcome": human_outcome,
        "related_run_key": None,
        "related_aoi_id": None,
        "dpa_code": None,
        "note": canonical_json({"reviews": decision_id, "note": note}),
    }


__all__ = [
    "Answer", "BackendUnavailableError", "BACKEND_POLICIES", "CircuitBreaker", "DataClassNotAllowedError",
    "DecisionBackend", "DecisionBackendError", "DecisionRequest", "DecisionResponse", "DecisionValidationError",
    "DEFAULT_MODEL", "DEFAULT_POLICY", "FALLBACK_POLICY", "FailoverBackend", "OpenWeightHTTPBackend", "PolicyDecision",
    "RateLimitedError", "SystemOneAdapterGeminiBackend", "SystemOneHTTPBackend", "TemplateError",
    "ThresholdPolicy", "TypeSafeHTTPBackend", "apply_choice", "apply_noul", "apply_score", "bucketise",
    "build_decision_log_rows", "build_human_review_row", "canonical_json", "combine_flags_max",
    "combine_parts_min", "evaluate", "gateway_backend", "google_id_token_provider", "parse_answers",
    "render_template", "request_sha256", "resolve_gate", "score_level", "validate_request",
]
