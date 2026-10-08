# Security policy

Please report vulnerabilities privately — never in a public issue.

- **GitHub:** *Security → Report a vulnerability* on this repository (private advisory).
- **Deployed twin:** the `/seguridad` page of the application (form), or the address in its `/.well-known/security.txt`.

We acknowledge reports within 5 business days and tell you when the fix is deployed. Please do not access other users' data, degrade the service or use social engineering, and give us reasonable time before disclosure.

Dependencies are audited on every change and weekly (`pip-audit`, Dependabot), and the deployed site gets a weekly passive OWASP ZAP baseline scan.
