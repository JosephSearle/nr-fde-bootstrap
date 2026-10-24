# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, Codex, Copilot, etc.) when working with code in this repository.

## What this repo is

`nr-fde-bootstrap`: a one-command setup for a new Apple Silicon Mac used by forward deployed engineers (FDEs). There is no application code. The repo is three pieces that must stay in sync:

- `Brewfile`: the Core tier tools (`brew` = CLI tools, `cask` = apps, `vscode` = extensions).
- `bootstrap.sh`: runs `brew bundle`, then installs what the Brewfile deliberately doesn't (Python via `uv python install`, global Python tools `ruff`/`pyright`/`pre-commit` via `uv tool install`, Node LTS via `fnm`), sets git's global `init.templateDir` so new clones install their pre-commit hooks, then verifies every command is on PATH and checks FileVault.
- `README.md`: the user-facing docs, including the "What gets installed" table that explains why each tool is there.

`.pre-commit-config.yaml` holds this repo's own commit checks. shellcheck and gitleaks are `repo: local` hooks that use the installed binaries on purpose: pre-commit's usual hooks for them download large files from GitHub, which failed on our network. Don't switch them back without testing that.

**Adding a tool touches all three:** add it to `Brewfile`, add its command to the `for cmd in ...` PATH check in `bootstrap.sh`, and add a row to the README's "What gets installed" table. Tools not everyone needs go in the README's "Beyond the Core tier" table instead and stay out of the Brewfile. Don't add Node via Homebrew; fnm manages it.

## Commands

```bash
pre-commit run --all-files    # whitespace, YAML, shellcheck, staged-secrets scan (CI runs this)
gitleaks git --no-banner --redact .   # secret scan over full history (CI runs this)
./bootstrap.sh --force        # real end-to-end test; --force needed off an up-to-date main
PYTHON_VERSION=3.13 ./bootstrap.sh --force   # override the default Python 3.12
SKIP_FILEVAULT_CHECK=1 ./bootstrap.sh --force # FileVault off reported but not fatal (CI sets this)
```

There is no unit test suite. `./bootstrap.sh` installs software, edits `~/.zshrc` and changes the global git config on the machine it runs on, so don't run it without the user's go-ahead. To test one step safely, point `GIT_CONFIG_GLOBAL` and `HOME` at a throwaway directory, and create any test repos inside that directory, never in this repo. CI (`.github/workflows/ci.yml`) runs `pre-commit run --all-files` and a full-history gitleaks scan, then runs the script twice on a clean `macos-latest` runner to prove it installs and is idempotent.

## bootstrap.sh constraints

- **Must run on macOS's stock bash 3.2.** No `${x,,}`, associative arrays, `mapfile`, etc. (see the `tr` lowercase workaround in `check_clean_clone`). Runs under `set -euo pipefail`.
- **Must stay idempotent**; CI re-runs it, then diffs `~/.zshrc`, `~/.zshenv`, the other shell startup files, `git config --global` and `~/.git-template` against the first run, and fails on any change. Guard every append to shell config, and make the guard ignore commented-out lines: the fnm check uses `grep -q '^[^#]*fnm env'`, the `~/.local/bin` check matches the exact whole line it writes with `grep -qxF`. Write zsh config to `$ZSHRC` (which honours `ZDOTDIR`), and use `$UV_PYTHON_BIN`/`$UV_TOOL_BIN` (asked from uv, so `XDG_BIN_HOME` etc. are honoured) rather than hard-coding `~/.local/bin`.
- **Clean-clone guard** (`check_clean_clone`): refuses to run unless the script is in a git clone whose `origin` is `NR-AI-Delivery/nr-fde-bootstrap`, `Brewfile`/`bootstrap.sh` have no uncommitted changes, and HEAD is either `main` matching origin (not behind, no local commits) or the newest release tag on origin (a plain version like `v1.2.3`, compared ignoring a leading `v`; rc and other tags are ignored). Offline, `main` is checked against the last-fetched `origin/main`, and a tag is refused. Its network calls give up on a stalled connection using git's `http.lowSpeedLimit`/`http.lowSpeedTime` and ssh's `ConnectTimeout`/`ServerAlive*` options, and add those ssh options plus `BatchMode=yes` to the user's own ssh command (`GIT_SSH_COMMAND` or `core.sshCommand`) instead of replacing it. It runs after the prerequisites step, because `git` doesn't work without the Command Line Tools. It's a guardrail, not a security boundary; `--force` bypasses it (CI uses `--force` because PR checkouts are detached merge commits).
- The PATH check verifies commands rather than trusting `brew bundle`, because an interrupted cask install still reports "Using". Missing tools are collected and the script fails at the very end, so one failure doesn't hide the rest of the report. Install commands run through `attempt`, which records a failure in `FAILED` and carries on for the same reason; use it for any new install command.
- `--help` prints lines 2–5 of the script via `sed`, so keep the usage header comment at the top in that shape.
- Each step starts with `step "..."` which prints a numbered `==> [n/total]` heading. The total comes from counting `^step "` lines in the script, so keep step calls unindented. The "Done" heading isn't a step and is printed directly. The README's "Usage" section shows sample output, so update it if step names, the step count or the final message change.
- Use the output helpers rather than bare `echo` for results: `ok` (✓), `bad` (✗), `note` and `die` (✗ then exit 1). Colour is on only when stdout is a terminal and `NO_COLOR` is unset. An `EXIT` trap reports which step a `set -e` failure stopped in; a deliberate exit sets `EXPLAINED=1` first (`die` does this) so the trap stays quiet.

## Repo process

- PRs to `main` only; `CODEOWNERS` requires `@NR-AI-Delivery/nr-ai-delivery-team` approval. The PR template checklist asks for: `pre-commit run --all-files` passing, a `--force` run on a Mac, the three-file sync above, and no secrets, tokens or internal hostnames.
- The GitHub Enterprise host is deliberately a placeholder (`<ghe-host>`) in the README; don't fill in a real internal hostname.
- The README's "Open decisions" section lists unsettled choices (Pyright vs `ty`, Python 3.12 vs 3.13, Biome vs ESLint+Prettier, etc.); don't change those defaults unprompted.
