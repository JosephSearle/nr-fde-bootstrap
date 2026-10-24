# Security Policy

`nr-fde-bootstrap` installs software and changes settings on every FDE's
laptop, so a problem here spreads to the whole team. Please report anything
that could compromise those laptops.

## Reporting a vulnerability

**Report privately through GitHub:** open this repo's **Security** tab and
choose **Report a vulnerability**. Only the repo's maintainers can see the
report.

Don't open a public issue or pull request, and don't post details in Slack
channels, until a fix is merged.

<!-- TODO (maintainers): turn on private vulnerability reporting in
Settings > Code security, or this button won't appear. -->

### If you committed a secret

Revoke or rotate it **first**, then report it. Deleting the commit or
rewriting history doesn't help: anyone who cloned the repo or saw the push
may already have it.

## What to include

- What the problem is and why it matters
- The file and line, or the Brewfile entry, involved
- How to reproduce it, including your macOS version
- The commit you were on (`git rev-parse HEAD`)
- Any workaround you know of

## What to report here

Report it here if this repo:

- installs something malicious, compromised or from an untrusted source
- weakens a laptop's security, for example by loosening file permissions,
  changing system security settings or putting an unsafe directory on `PATH`
- contains a secret, token or internal hostname
- could be tampered with without review, for example through a gap in
  `CODEOWNERS` or the branch rules

The clean-clone check in `bootstrap.sh` is a guardrail, not a security
boundary, so bypassing it with `--force` isn't a vulnerability.

### Report these elsewhere

- **A vulnerability in a tool this repo installs** (uv, Node, Docker
  Desktop, VS Code and so on): report it to that tool's maintainers. Tell us
  as well if we should pin, replace or remove the tool.
- **A problem with your laptop that this repo didn't cause:** contact IT.

## Supported versions

Only the latest `main` and the newest release tag are supported. Fixes go to
`main`, so pull before re-running. `bootstrap.sh` refuses to run from
anything else. If it can't reach GitHub, it refuses a tag, and on `main` it
compares against the last-fetched `origin/main`, which may be out of date.

## What happens next

The maintainers ([@NR-AI-Delivery/nr-ai-delivery-team](.github/CODEOWNERS))
take every report seriously, but there's no guaranteed response time. They'll
confirm the issue, fix it on `main`, and tell FDEs if anyone needs to re-run
the bootstrap or rotate credentials.

If you don't get a response, or the issue is urgent, escalate to the company
security team.

<!-- TODO: add the security team's contact (email, portal or Slack channel). -->
