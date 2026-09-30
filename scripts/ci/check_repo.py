#!/usr/bin/env python3
"""Repository checks used in CI.

Mermaid blocks render (unless --links-only), relative links and anchors resolve,
each markdown file has one H1, and YAML/JSON/Python/bash/HCL files parse.
Run: python3 scripts/ci/check_repo.py [--links-only]
"""
import glob, json, os, re, subprocess, sys, py_compile

REPO = os.environ.get("REPO_ROOT") or os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MMDC = os.environ.get("MMDC", "mmdc")
PCFG = os.environ.get("PUPPETEER_CONFIG", "")
OUT = os.environ.get("CHECK_OUT", "/tmp/check_repo_out")
os.makedirs(OUT, exist_ok=True)

errors = []
md_files = sorted(glob.glob(f"{REPO}/*.md") + glob.glob(f"{REPO}/docs/*.md") + glob.glob(f"{REPO}/outreach/**/*.md", recursive=True) + glob.glob(f"{REPO}/**/README.md", recursive=True))
md_files = sorted(set(md_files))

# 1. Mermaid
only_mermaid = "--links-only" not in sys.argv
md_files = [f for f in md_files if "/node_modules/" not in f and "/.terraform/" not in f]
if only_mermaid:
    for f in md_files:
        text = open(f, encoding="utf-8").read()
        blocks = re.findall(r"```mermaid\n(.*?)```", text, re.S)
        for i, b in enumerate(blocks):
            name = f"{os.path.basename(f)}_{i}"
            src = os.path.join(OUT, name + ".mmd")
            open(src, "w").write(b)
            cmd = [MMDC] + (["-p", PCFG] if PCFG else []) + ["-i", src, "-o", os.path.join(OUT, name + ".svg"), "-q"]
            r = subprocess.run(cmd,
                               capture_output=True, text=True, timeout=120)
            if r.returncode != 0:
                msg = (r.stderr or r.stdout).strip().splitlines()
                errors.append(f"MERMAID {os.path.relpath(f, REPO)} block#{i}: " + " | ".join(msg[:6]))

# 2. Relative links
for f in md_files:
    text = open(f, encoding="utf-8").read()
    # strip code blocks
    text_nc = re.sub(r"```.*?```", "", text, flags=re.S)
    for m in re.finditer(r"\[[^\]]*\]\(([^)\s]+)\)", text_nc):
        target = m.group(1)
        if re.match(r"^(https?:|mailto:|#)", target):
            continue
        path = target.split("#")[0]
        if not path:
            continue
        full = os.path.normpath(os.path.join(os.path.dirname(f), path))
        if not os.path.exists(full):
            errors.append(f"LINK {os.path.relpath(f, REPO)} -> {target} (missing)")
        anchor = target.split("#")[1] if "#" in target else None
        if anchor and os.path.exists(full) and full.endswith(".md"):
            heads = re.findall(r"^#+\s+(.*)$", open(full, encoding="utf-8").read(), re.M)
            def slug(h):
                h = h.strip().lower()
                h = re.sub(r"[^\w\- ]", "", h, flags=re.U)
                return h.replace(" ", "-")
            if anchor not in {slug(h) for h in heads}:
                errors.append(f"ANCHOR {os.path.relpath(f, REPO)} -> {target} (anchor not found)")

# 3. H1 count
for f in md_files:
    text = re.sub(r"```.*?```", "", open(f, encoding="utf-8").read(), flags=re.S)
    h1 = re.findall(r"^# ", text, re.M)
    if len(h1) != 1:
        errors.append(f"H1 {os.path.relpath(f, REPO)} has {len(h1)} H1 headings")

# 4. Data/code files
try:
    import yaml
    for f in glob.glob(f"{REPO}/**/*.y*ml", recursive=True):
        try:
            yaml.safe_load(open(f))
        except Exception as e:
            errors.append(f"YAML {os.path.relpath(f, REPO)}: {e}")
except ImportError:
    pass
for f in glob.glob(f"{REPO}/**/*.json", recursive=True):
    try:
        json.load(open(f))
    except Exception as e:
        errors.append(f"JSON {os.path.relpath(f, REPO)}: {e}")
for f in [x for x in glob.glob(f"{REPO}/**/*.py", recursive=True) if "/.venv/" not in x and "/node_modules/" not in x]:
    try:
        py_compile.compile(f, doraise=True, cfile=os.path.join(OUT, "x.pyc"))
    except Exception as e:
        errors.append(f"PY {os.path.relpath(f, REPO)}: {e}")
for f in glob.glob(f"{REPO}/**/*.sh", recursive=True):
    r = subprocess.run(["bash", "-n", f], capture_output=True, text=True)
    if r.returncode != 0:
        errors.append(f"BASH {os.path.relpath(f, REPO)}: {r.stderr.strip()}")
try:
    import hcl2
    for f in [x for x in glob.glob(f"{REPO}/**/*.tf", recursive=True) if "/.terraform/" not in x]:
        try:
            hcl2.load(open(f))
        except Exception as e:
            errors.append(f"HCL {os.path.relpath(f, REPO)}: {str(e)[:200]}")
except ImportError:
    errors.append("HCL parser not installed")

print(f"Checked {len(md_files)} markdown files")
for e in errors:
    print(e)
print(f"{len(errors)} problems")
sys.exit(1 if errors else 0)
