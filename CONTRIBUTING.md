# Contributing to nr-fde-bootstrap

This repo is how every new FDE gets a working laptop, so each improvement
saves the next person time. You don't have to change code to help:

- **Fixing or clarifying the README** is as valuable as changing the script.
- **Reporting what tripped you up** during setup helps, even if you worked
  around it. The [Known gotchas](README.md#known-gotchas) list came from
  exactly that.
- **Testing a change** on your own Mac before it merges catches what CI can't.

## Ground rules

- **Every change goes through a pull request to `main`.** Direct pushes are
  blocked, and [@NR-AI-Delivery/nr-ai-delivery-team](.github/CODEOWNERS)
  approves every PR.
- **Core means everyone needs it on day one.** Anything only some FDEs need
  belongs in the README's
  [Beyond the Core tier](README.md#beyond-the-core-tier) table, not in the
  Brewfile.
- **Keep three things in sync.** A tool in the [`Brewfile`](Brewfile) needs
  its command in the PATH check in [`bootstrap.sh`](bootstrap.sh) and a row
  in the README's [What gets installed](README.md#what-gets-installed) table.
- **Never commit secrets, tokens or internal hostnames.** CI scans for
  secrets, but it can't recognise a hostname.

There's no separate code of conduct for this repo; company policies apply.

## Where to ask questions

Ask the maintainers before opening an issue for anything that isn't clearly a
bug or a proposal.

<!-- TODO: add the team's Slack channel or other chat link. -->

## Small changes and big changes

- **Small changes** such as typos, wording and broken links: open a PR
  directly.
- **Big changes** such as adding or removing a Core tool, or changing what
  `bootstrap.sh` does: start a conversation with the maintainers first.
  Every Core tool lands on every FDE's laptop, so it's worth agreeing before
  anyone writes the change.

## Set up for development

You need a Mac that has already run the bootstrap. Then:

1. Clone the repo and create a branch:

   ```bash
   gh repo clone NR-AI-Delivery/nr-fde-bootstrap
   ```

   ```bash
   cd nr-fde-bootstrap && git checkout -b add-direnv
   ```

2. Install shellcheck. The pre-commit hooks need it, but not every FDE does,
   so it isn't in the Brewfile:

   ```bash
   brew install shellcheck
   ```

The bootstrap set git up to install this repo's pre-commit hooks when you
cloned it. If you cloned it *before* running the bootstrap, turn them on
once:

```bash
pre-commit install
```

From then on, every `git commit` checks the files you changed: whitespace,
YAML syntax, merge-conflict markers, shellcheck on the script, and gitleaks
on the staged changes. The hooks are set in
[`.pre-commit-config.yaml`](.pre-commit-config.yaml).

## Test your change

Run both before opening a PR. These are the same checks CI runs.

1. **Run the pre-commit checks on every file:**

   ```bash
   pre-commit run --all-files
   ```

   Every line should end in `Passed`. If a whitespace or end-of-file hook
   says `Failed`, it has already fixed the file; review the change and run
   it again.

2. **Run the bootstrap.** `--force` is needed because you're on a branch,
   not `main`:

   ```bash
   ./bootstrap.sh --force
   ```

   It should end with a green `==> Done. Next manual steps:` and exit with
   status 0 (check with `echo $?`). A ✗ anywhere above that, including
   FileVault being off, makes the run fail. Then **run it a second
   time**. It must be safe to re-run, and second-run bugs are easy to miss.

For a docs-only change, step 1 is enough.

## Rules for bootstrap.sh

- **It must work with macOS's built-in bash 3.2.** That rules out bash 4
  features such as `${var,,}` or `declare -A`. If you've installed a newer
  bash with Homebrew, test with `/bin/bash ./bootstrap.sh --force`.
- **It must be safe to re-run.** Check before you change anything, as the
  `~/.zshrc` edit does, rather than appending every time.
- **Check the commands themselves, not Homebrew's output.** `brew bundle`
  can report an interrupted install as installed, which is why the script
  checks each command is on `PATH`.
- **Report everything, then fail.** A missing tool shouldn't stop the
  script before the rest of the report prints.

## Report a bug

**If it's a security problem, don't file it here.** Follow
[SECURITY.md](SECURITY.md) instead.

For anything else, open an issue in this repo with:

- What you ran, and whether it was a first run or a re-run
- The commit you were on (`git rev-parse HEAD`)
- Your macOS version and Mac model
- The `==>` step that failed, and its output
- What you expected to happen

<!-- TODO: update if the team tracks work in something other than GitHub
Issues. -->

## Propose a new tool

Say:

- **What it is, and how it's installed:** a `brew` formula, a `cask`, a uv
  tool or a VS Code extension.
- **Why every FDE needs it on day one,** or which tier it belongs in instead.
- **What you considered instead.** For example, fnm was chosen over nvm, and
  Docker Desktop over OrbStack.
- **Its license and cost.** Docker Desktop, for example, needs paid seats.

## Pull request process

1. Open a PR against `main` and fill in the
   [template](.github/pull_request_template.md).
2. CI runs two jobs:
   - **lint:** the same pre-commit checks on every file, plus a gitleaks
     scan of the full history.
   - **bootstrap:** the script runs twice on a clean macOS runner.
3. A member of @NR-AI-Delivery/nr-ai-delivery-team reviews it. There's no
   guaranteed review time.
4. Once it's approved and CI passes, it's merged to `main`. FDEs pick it up
   the next time they `git pull` and re-run the bootstrap.
