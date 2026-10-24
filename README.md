<div align="center">

# NewRocket FDE Bootstrap

<!-- The CI badge uses relative links so the GitHub Enterprise hostname stays
out of the repo. TODO: check it renders after the first push.
Keep the Python badge in sync with PYTHON_VERSION in bootstrap.sh. -->
[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)
[![pre-commit: enabled](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](.pre-commit-config.yaml)
[![macOS: Apple Silicon](https://img.shields.io/badge/macOS-Apple%20Silicon-000000?logo=apple)](#dependencies)
[![Python: 3.12](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](#python-and-node-side-by-side)
[![Node.js: LTS](https://img.shields.io/badge/Node.js-LTS-5FA04E?logo=nodedotjs&logoColor=white)](#python-and-node-side-by-side)
[![License: UNLICENSED](https://img.shields.io/badge/license-UNLICENSED-lightgrey)](#license)

</div>

> One command to set up a new Mac for forward deployed AI engineering:
> Python, Node, Claude Code, VS Code, Docker and security tooling.

Every forward deployed engineer (FDE) builds AI solutions with Claude,
LangChain, LangGraph and whatever the customer's stack needs. This repo
makes sure everyone starts from the same, tested setup instead of a wiki page
that drifts. The [`Brewfile`](Brewfile) lists the tools,
[`bootstrap.sh`](bootstrap.sh) installs and checks them, and this README
explains what you get and why.

Built with:

- [Homebrew](https://brew.sh) and `brew bundle`
- [uv](https://docs.astral.sh/uv/) for Python
- [fnm](https://github.com/Schniz/fnm) and [pnpm](https://pnpm.io) for Node

<details>
<summary>Table of Contents</summary>

- [Security](#security)
- [Install](#install)
  - [Dependencies](#dependencies)
  - [Steps](#steps)
- [Usage](#usage)
  - [CLI](#cli)
- [What gets installed](#what-gets-installed)
  - [Changes to your settings](#changes-to-your-settings)
- [Python and Node side by side](#python-and-node-side-by-side)
- [AI frameworks and SDKs](#ai-frameworks-and-sdks)
- [Known gotchas](#known-gotchas)
- [Beyond the Core tier](#beyond-the-core-tier)
- [Open decisions](#open-decisions)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)

</details>

## Security

To report a vulnerability, see [SECURITY.md](SECURITY.md). Don't open a
public issue.

- **Run it from a clean clone.** `bootstrap.sh` refuses to run if it isn't in
  a git clone of this repo, if `Brewfile` or `bootstrap.sh` has local
  changes (committed or not), or if you're not on an up-to-date `main` or the
  latest release tag. This
  catches stale copies and files shared outside the repo. It's a guardrail,
  not a security boundary: `--force` overrides it.
- **Changes are reviewed.** `main` is protected, and
  [`CODEOWNERS`](.github/CODEOWNERS) requires approval from
  @NR-AI-Delivery/nr-ai-delivery-team for every change.
- **Never commit secrets.** API keys go in environment variables or a secret
  manager, never in this repo or your dotfiles. CI runs gitleaks on every PR.
- **FileVault must be on** before any customer data touches the laptop. The
  script checks it but can't turn it on; IT's MDM enforces it.
- **Docker Desktop needs a paid license** for companies with more than 250
  employees or $10M in revenue. Confirm you have a seat with IT.

## Install

### Dependencies

- A Mac with Apple Silicon, on macOS 26 or later
- Admin rights on the Mac (Docker Desktop asks for your password)
- Access to this repo on GitHub Enterprise
- Room for several large apps: Docker Desktop alone is a 600 MB download

### Steps

1. Install Apple's Command Line Tools, which include git:

   ```bash
   xcode-select --install
   ```

2. Install Homebrew by following the one-line installer at
   [brew.sh](https://brew.sh).

3. Install the GitHub CLI and sign in to GitHub Enterprise:

   ```bash
   brew install gh
   ```

   ```bash
   gh auth login --hostname <ghe-host>
   ```

   Replace `<ghe-host>` with the company's GitHub Enterprise hostname.
   It's left out of this repo on purpose, so internal hostnames stay out of
   version control. If it wasn't in your onboarding details, ask the
   maintainers (the NR AI Delivery team).

4. Clone this repo:

   ```bash
   gh repo clone NR-AI-Delivery/nr-fde-bootstrap ~/nr-fde-bootstrap
   ```

## Usage

Run the bootstrap from the clone:

```bash
cd ~/nr-fde-bootstrap && ./bootstrap.sh
```

It's safe to re-run at any time, for example after pulling an update. Each
step prints a numbered `==>` heading, and results are marked ✓ or ✗ (in
colour in a terminal; set `NO_COLOR=1` to turn colour off). If an install
command fails, such as a cask in `brew bundle`, the script carries on and
lists it at the end. If anything else fails, it says which step it stopped
at. A successful run ends like this:

```text
==> [9/10] Verifying commands are on PATH
  ✓ git          ✓ gh           ✓ rg           ✓ fd           ✓ jq
  ✓ uv           ✓ gitleaks     ✓ code         ✓ claude       ✓ docker
  ✓ ruff         ✓ pyright      ✓ pre-commit   ✓ fnm          ✓ node
  ✓ npm          ✓ npx          ✓ pnpm
  ✓ python3 3.12.x (uv)
✓ All Core commands found.

==> [10/10] Checking FileVault
✓ FileVault is On.

==> Done. Next manual steps:
  1. Open a new terminal so PATH changes apply.
  2. gh auth login --hostname <ghe-host>   (see README > Install > Steps)
  3. claude   (sign in to Claude Code)
  4. If FileVault is Off: System Settings > Privacy & Security > FileVault
  5. In repos you cloned before today, run: pre-commit install
```

If any tool is missing, an install failed or FileVault is off, the script
lists it, suggests a fix and exits with status 1. Either way, do the manual steps it prints, and open Docker.app once
to accept its terms.

### CLI

```text
./bootstrap.sh [--force]
```

| Option | What it does |
|---|---|
| `--force` | Run even if the clean-clone checks fail. Use it only when testing changes to this repo. |
| `-h`, `--help` | Show usage. |
| `PYTHON_VERSION=3.13 ./bootstrap.sh` | Install a different Python version (default `3.12`). |
| `SKIP_FILEVAULT_CHECK=1 ./bootstrap.sh` | Report FileVault being off without failing the run. For CI runners, which can't turn it on. |

## What gets installed

Everything below is the **Core** tier: what every FDE needs on day one.

| Area | Tool | Why |
|---|---|---|
| Foundations | git, GitHub CLI (`gh`) | Version control, GitHub Enterprise sign-in and SSO, PRs from the terminal |
| | ripgrep, fd, jq | Fast search, file finding and JSON. Claude Code relies on ripgrep |
| Python | uv | Python versions, virtual environments, dependencies and lockfiles. Replaces pyenv, pip, venv, pipx and poetry |
| | Python 3.12 (through uv) | Never use the system Python, which is too old. `python3` runs this one after the bootstrap |
| | Ruff, Pyright | Lint and format, and type checking |
| Node | fnm | Node version manager. Reads `.nvmrc` and `.node-version` and switches on `cd`. Faster than nvm |
| | Node LTS (through fnm) | TypeScript projects, MCP servers, Claude Code plugins, frontends. Don't `brew install node`; let fnm manage it |
| | pnpm | Default package manager: fast, disk-efficient and strict. npm still comes with Node |
| Editor and AI | VS Code | Team editor |
| | Claude Code | Agentic coding in the terminal and VS Code |
| | VS Code extensions | Python, Pylance, Ruff, Biome, GitLens, GitHub Pull Requests, Claude Code, Docker, Dev Containers |
| Containers | Docker Desktop | Team container runtime |
| Security and quality | gitleaks | Finds secrets before they're committed |
| | pre-commit | Runs a repo's checks, such as gitleaks and linters, on every commit. Switched on automatically for repos you clone (see below) |

In the [`Brewfile`](Brewfile), `brew` lines are command-line tools, `cask`
lines are prebuilt apps (mostly in `/Applications`; `claude-code` is a
command-line tool shipped as a cask), and `vscode` lines are VS Code
extensions. Python tools, including pre-commit, and Node itself are installed
by `bootstrap.sh`, not the Brewfile, so uv and fnm can manage their versions.

### Changes to your settings

Besides installing tools, the bootstrap changes three settings. All are safe
to re-run:

- **`~/.zshrc`** (or `$ZDOTDIR/.zshrc` if you set `ZDOTDIR`): adds one line
  so fnm switches Node versions when you `cd` into a project, and one that
  puts `~/.local/bin` first on your `PATH`, so `python3` is uv's Python
  rather than the system one. (macOS's `/etc/zprofile` otherwise moves the
  system folders back in front.) If you've pointed uv elsewhere with
  `XDG_BIN_HOME`, `UV_PYTHON_BIN_DIR` or `UV_TOOL_BIN_DIR`, it uses those
  folders instead.
- **Your shell's startup file (for zsh, `~/.zshenv`):** `uv tool update-shell`
  adds `~/.local/bin` to your `PATH`, where `ruff`, `pyright` and `pre-commit`
  live. It does nothing if that's already there.
- **git's `init.templateDir`:** set to `~/.git-template`, so every repo you
  clone or create from now on installs its pre-commit hooks automatically.
  The folder starts as a copy of git's default template, so new repos still
  get `.git/info/exclude`. A repo without a `.pre-commit-config.yaml` is
  unaffected. If you've already
  set `init.templateDir` to something else, or set `GIT_TEMPLATE_DIR`
  (which overrides it), the bootstrap leaves it alone.

## Python and Node side by side

Both stacks follow the same pattern: one tool manages runtime versions, each
project pins its versions in files, and there's one linter/formatter and one
test runner. Default to TypeScript for Node work, just as we type-check
Python. Packages in this table are added per project (`uv add`,
`pnpm add`), not installed globally.

| Job | Python | Node / TypeScript |
|---|---|---|
| Runtime version manager | uv | fnm |
| Version pinned per project | `.python-version` | `.nvmrc` or `.node-version` |
| Package manager and lockfile | uv (`uv.lock`) | pnpm (`pnpm-lock.yaml`) |
| Run a tool without installing it | `uvx` | `pnpm dlx`, or `npx` outside pnpm projects |
| Lint and format | Ruff | Biome |
| Type checking | Pyright | TypeScript (`tsc --noEmit`) |
| Tests | pytest | Vitest |
| Run a script directly | `uv run` | `tsx` |
| Validation and structured output | Pydantic | Zod |

## AI frameworks and SDKs

| Purpose | Python | Node / TypeScript |
|---|---|---|
| Claude API | `anthropic` | `@anthropic-ai/sdk` |
| Claude Agent SDK | `claude-agent-sdk` | `@anthropic-ai/claude-agent-sdk` |
| LangGraph | `langgraph` | `@langchain/langgraph` |
| LangChain with Claude | `langchain-anthropic` | `@langchain/anthropic` |
| MCP | `mcp` | `@modelcontextprotocol/sdk` |

**Rule of thumb:** start with the Claude SDK. Add LangGraph when you need
stateful agents, checkpointing or a human approval step. Add LangChain only
for a specific integration you need.

## Known gotchas

- **pnpm blocks dependency install scripts until you approve them.** It's a
  supply-chain protection, so keep it on. The first time a package such as
  esbuild (used by tsx and Vitest) wants to run one, `pnpm add` exits with
  `ERR_PNPM_IGNORED_BUILDS`. Run `pnpm approve-builds`, which records the
  approval in `pnpm-workspace.yaml`, and commit that file.
- **Use `pnpm dlx`, not `npx`, inside pnpm projects.** `pnpm init` marks a
  project as pnpm-only, so npm refuses to run there.
- **TypeScript's `NodeNext` module setting needs `.js` on relative imports.**
  Write `import { sum } from "./sum.js"` even though the file is `sum.ts`.
- **If the script reports `docker` missing, open Docker.app once.** On first
  launch it installs its command-line tools to `~/.docker/bin` and adds that
  to `~/.zprofile`, with no password needed. Then open a new terminal. If
  that doesn't work, run `brew reinstall --cask docker-desktop` and enter
  your password.
- **Repos you cloned before running the bootstrap don't have hooks yet.** Run
  `pre-commit install` once in each. New clones get them automatically.
- **Hooks can be skipped** with `git commit --no-verify`, so CI must run the
  same checks. A repo that uses a different hook manager (husky, lefthook)
  manages its own hooks; follow that repo's README.
- **gitleaks ignores AWS's documented `EXAMPLE` keys.** Use a random fake
  token if you want to test that it works.

## Beyond the Core tier

Install these when an engagement needs them. They aren't in the Brewfile.

| Tier | Tool | Install | When |
|---|---|---|---|
| Standard | Cloud CLIs | `brew install awscli`, `google-cloud-sdk` or `azure-cli` | Whichever cloud the customer uses |
| Standard | Postgres client | `brew install libpq` | Common backing store |
| Standard | direnv | `brew install direnv` | Per-project environment variables without committing `.env` |
| Standard | just | `brew install just` | One `just test` / `just lint` across repos |
| Optional | OpenTofu | `brew install opentofu` | Engagements that own infrastructure |
| Optional | mise | `brew install mise` | Projects pinning many runtimes (Go, Java) |

## Open decisions

1. Type checker: Pyright (current default) or Astral's `ty`.
2. Default observability and evals platform: LangSmith, Langfuse or
   Braintrust.
3. Docker Desktop license seats.
4. Ship this as `Brewfile` + `bootstrap.sh` only, or also as a Claude Code
   skill that runs it.
5. Python baseline: 3.12 or 3.13.
6. Node linting: Biome, or ESLint + Prettier as the team standard.
7. A shared `CLAUDE.md` and Claude Code settings for all FDE repos.

## Maintainers

[@NR-AI-Delivery/nr-ai-delivery-team](.github/CODEOWNERS) reviews and
approves all changes.

## Contributing

Improvements are welcome, including fixes to these docs. Changes go through
pull requests to `main`. See [CONTRIBUTING.md](CONTRIBUTING.md) for how to
test a change, the rules `bootstrap.sh` must follow, and how to propose a new
tool.

## License

UNLICENSED. Internal use only; not for distribution.

<!-- TODO: name the copyright owner, e.g. "Copyright 2026 <company name>". -->
