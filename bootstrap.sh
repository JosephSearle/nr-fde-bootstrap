#!/usr/bin/env bash
# FDE Core tier bootstrap. Safe to re-run.
#
# Usage: ./bootstrap.sh [--force]
#   --force  Run even if the clean-clone checks fail (for testing changes).
set -euo pipefail

PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
# With CDPATH set, cd can print the directory, which would end up in SCRIPT_DIR.
unset CDPATH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# The repo this script must be cloned from, as "<org>/<repo>".
EXPECTED_REPO="NR-AI-Delivery/nr-fde-bootstrap"
RELEASE_BRANCH="main"

# Colour only on a terminal, so CI logs and piped output stay plain, and
# honour NO_COLOR (https://no-color.org).
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
  BOLD=$'\033[1m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' BLUE=$'\033[34m' RESET=$'\033[0m'
else
  BOLD="" RED="" GREEN="" YELLOW="" BLUE="" RESET=""
fi

# For the [n/total] counter, count the step calls in this file. Only calls at
# the start of a line match, so keep them unindented.
STEP_TOTAL="$(grep -c '^step "' "$SCRIPT_DIR/bootstrap.sh")"
STEP_NUM=0
STEP_NAME=""
step() {
  STEP_NUM=$((STEP_NUM + 1))
  STEP_NAME="$*"
  printf '\n%s==>%s %s[%d/%d] %s%s\n' "$BLUE" "$RESET" "$BOLD" "$STEP_NUM" "$STEP_TOTAL" "$*" "$RESET"
}
ok()   { printf '%s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
bad()  { printf '%s✗ %s%s\n' "$RED" "$*" "$RESET"; }
note() { printf '%sNote:%s %s\n' "$YELLOW" "$RESET" "$*"; }
# For exits that have already said what's wrong.
die()  { bad "$*"; EXPLAINED=1; exit 1; }

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help) sed -n '2,5p' "$SCRIPT_DIR/bootstrap.sh" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) bad "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# Run an install command. If it fails, record it and carry on, so one failed
# cask or blocked download doesn't hide the rest of the report. The script
# still fails at the end.
FAILED=()
attempt() {
  local status=0
  "$@" || status=$?
  if (( status != 0 )); then
    bad "Failed with exit status $status: $*"
    FAILED+=("$*")
  fi
}

# If a command fails partway (set -e), say which step it was in, since its
# own error can scroll by in a long brew bundle log.
EXPLAINED=0
on_exit() {
  local status=$?
  if (( status != 0 && ! EXPLAINED && STEP_NUM > 0 )); then
    printf '\n'
    bad "Stopped at step $STEP_NUM/$STEP_TOTAL ($STEP_NAME), exit status $status."
    echo "Fix the error above, then re-run ./bootstrap.sh. It's safe to re-run."
  fi
}
trap on_exit EXIT

# Where uv puts its tools and python3. ~/.local/bin unless XDG_BIN_HOME,
# UV_TOOL_BIN_DIR or UV_PYTHON_BIN_DIR says otherwise; set_uv_bin_dirs asks
# uv once it's installed. They go on PATH because uv tool update-shell errors
# if the tool folder is in shell config but not PATH.
UV_TOOL_BIN="$HOME/.local/bin"
UV_PYTHON_BIN="$HOME/.local/bin"
set_uv_bin_dirs() {
  if command -v uv >/dev/null 2>&1; then
    UV_TOOL_BIN="$(uv tool dir --bin 2>/dev/null || echo "$UV_TOOL_BIN")"
    UV_PYTHON_BIN="$(uv python dir --bin 2>/dev/null || echo "$UV_PYTHON_BIN")"
  fi
  export PATH="$UV_PYTHON_BIN:$UV_TOOL_BIN:$PATH"
}
set_uv_bin_dirs

# zsh reads its startup files from $ZDOTDIR if that's set.
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
# Paths shown to the user, with $HOME as ~.
tildify() {
  case "$1" in
    "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# Guardrail, not a security boundary: catches stale copies, local edits and
# files passed around outside the repo. --force overrides it.
check_clean_clone() {
  local git=(git -C "$SCRIPT_DIR")
  # For network calls: fail instead of prompting for credentials, and give up
  # on a stalled connection (dead VPN, captive portal), since a hidden prompt
  # or a stall would look like a hang. Keep the user's own ssh command, such
  # as a core.sshCommand that picks their GHE key, and only add options.
  local ssh_cmd
  ssh_cmd="${GIT_SSH_COMMAND:-$("${git[@]}" config --get core.sshCommand 2>/dev/null || true)}"
  local remote_git=(env GIT_TERMINAL_PROMPT=0)
  # GIT_SSH_COMMAND would override GIT_SSH, so leave a GIT_SSH setup alone.
  if [[ -n "$ssh_cmd" || -z "${GIT_SSH:-}" ]]; then
    remote_git+=(GIT_SSH_COMMAND="${ssh_cmd:-ssh} -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=5 -o ServerAliveCountMax=2")
  fi
  remote_git+=(git -C "$SCRIPT_DIR" -c http.lowSpeedLimit=1 -c http.lowSpeedTime=20)
  local problems=()

  if ! "${git[@]}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    problems+=("Not a git clone. Clone the repo instead of copying the files.")
  else
    local origin
    origin="$("${git[@]}" remote get-url origin 2>/dev/null || true)"
    origin="${origin%/}"
    origin="${origin%.git}"
    # GitHub names are case-insensitive; macOS bash 3.2 has no ${x,,}.
    local lc_origin lc_expected
    lc_origin="$(printf '%s' "$origin" | tr '[:upper:]' '[:lower:]')"
    lc_expected="$(printf '%s' "$EXPECTED_REPO" | tr '[:upper:]' '[:lower:]')"
    # Only a remote on a server counts: https://host/<org>/<repo>,
    # ssh://host/<org>/<repo> or [user@]host:<org>/<repo> (no user when host
    # is an ~/.ssh/config alias). The org must come straight after the host,
    # so "notacme/x" isn't "acme/x", and a local path like
    # /tmp/copy/<org>/<repo> doesn't pass.
    local origin_re="^(https://[^/]+/|ssh://[^/]+/|([^/@:]+@)?[^/@:]+:)$lc_expected\$"
    if ! [[ "$lc_origin" =~ $origin_re ]]; then
      problems+=("Remote 'origin' is '${origin:-none}', expected $EXPECTED_REPO.")
    fi

    if [[ -n "$("${git[@]}" status --porcelain -- Brewfile bootstrap.sh)" ]]; then
      problems+=("Brewfile or bootstrap.sh has local changes.")
    fi

    local branch head
    branch="$("${git[@]}" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    head="$("${git[@]}" rev-parse --verify --quiet HEAD || true)"
    if [[ "$branch" == "$RELEASE_BRANCH" ]]; then
      # Compare with FETCH_HEAD, not origin/main: the fetch only updates
      # origin/main if the clone's refspec covers it. Offline, fall back to the
      # last-fetched origin/main so committed local edits are still caught,
      # and refuse if there's nothing to compare with.
      local base=""
      if "${remote_git[@]}" fetch --quiet origin "$RELEASE_BRANCH" </dev/null 2>/dev/null; then
        base=FETCH_HEAD
      elif "${git[@]}" rev-parse --verify --quiet "refs/remotes/origin/$RELEASE_BRANCH" >/dev/null; then
        base="refs/remotes/origin/$RELEASE_BRANCH"
        note "Couldn't reach origin, so checking against the last-fetched origin/$RELEASE_BRANCH, which may be out of date."
      else
        problems+=("Couldn't reach origin, and there's no origin/$RELEASE_BRANCH to compare with.")
      fi
      if [[ -n "$base" ]]; then
        local behind ahead
        behind="$("${git[@]}" rev-list --count "HEAD..$base")"
        ahead="$("${git[@]}" rev-list --count "$base..HEAD")"
        if (( behind > 0 )); then
          problems+=("$behind commit(s) behind origin/$RELEASE_BRANCH. Run: git pull")
        fi
        if (( ahead > 0 )); then
          problems+=("$ahead local commit(s) not on origin/$RELEASE_BRANCH.")
        fi
      fi
    else
      # Off main, HEAD must be the newest release tag on origin. A local tag
      # or an old release doesn't count. Only plain version tags (v1.2, 1.2.3)
      # are releases, so an rc or a stray tag like "wip" is never "latest".
      local local_tag tags latest latest_sha
      local_tag="$("${git[@]}" describe --exact-match --tags HEAD 2>/dev/null || true)"
      if tags="$("${remote_git[@]}" ls-remote --tags origin </dev/null 2>/dev/null)"; then
        # Compare versions in awk, ignoring a leading "v": git's version sort
        # would rank "v1.0" above "2.0".
        latest="$(printf '%s\n' "$tags" | awk '
          function newer(a, b,  x, y, n, m, i) {
            n = split(a, x, "."); m = split(b, y, ".")
            for (i = 1; i <= (n > m ? n : m); i++)
              if (x[i] + 0 != y[i] + 0) return x[i] + 0 > y[i] + 0
            return 0
          }
          $2 ~ /^refs\/tags\/v?[0-9]+(\.[0-9]+)*$/ {
            t = $2; sub("refs/tags/", "", t); v = t; sub(/^v/, "", v)
            if (best == "" || newer(v, best_v)) { best = t; best_v = v }
          }
          END { print best }')"
        # For an annotated tag, the peeled "^{}" line holds the commit.
        latest_sha="$(printf '%s\n' "$tags" | awk -v t="refs/tags/$latest" '
          $2 == t "^{}" { peeled = $1 }
          $2 == t { sha = $1 }
          END { print (peeled != "" ? peeled : sha) }')"
        if [[ -n "$latest" && "$latest_sha" == "$head" ]]; then
          : # The latest release.
        elif [[ -n "$local_tag" && -n "$latest" ]]; then
          problems+=("Tag '$local_tag' isn't the latest release. Run: git fetch --tags && git checkout $latest")
        else
          problems+=("On '${branch:-detached HEAD}', not $RELEASE_BRANCH or the latest release tag.")
        fi
      elif [[ -n "$local_tag" ]]; then
        # Tags are local refs, so offline there's nothing trustworthy to
        # compare with: refuse rather than run an old or made-up tag.
        problems+=("Couldn't reach origin to check that tag '$local_tag' is the latest release.")
      else
        problems+=("On '${branch:-detached HEAD}', not $RELEASE_BRANCH or a release tag.")
      fi
    fi
  fi

  (( ${#problems[@]} == 0 )) && { ok "Clean clone."; return 0; }

  local problem
  for problem in "${problems[@]}"; do
    printf '  %s✗%s %s\n' "$RED" "$RESET" "$problem"
  done
  if (( FORCE )); then
    note "Continuing because of --force."
  else
    die "Fix the above, or re-run with --force if you're testing changes."
  fi
}

# Before the clean-clone check: without the Command Line Tools, /usr/bin/git
# fails or pops up an install dialog.
step "Checking prerequisites"
xcode-select -p >/dev/null 2>&1 || die "Apple's Command Line Tools aren't installed. Run: xcode-select --install"
# Homebrew's installer doesn't put /opt/homebrew/bin on PATH for this shell.
if ! command -v brew >/dev/null 2>&1 && [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  note "Homebrew isn't on your PATH. Add it with the 'Next steps' lines brew's installer printed."
fi
command -v brew >/dev/null 2>&1 || die "Install Homebrew first: https://brew.sh"

step "Checking this is a clean clone"
check_clean_clone

step "Installing Homebrew packages, casks and VS Code extensions"
attempt brew bundle --file="$SCRIPT_DIR/Brewfile"
# uv may be newly installed, so ask it where its folders are.
set_uv_bin_dirs

step "Installing Python $PYTHON_VERSION with uv"
# --default also installs python and python3 into $UV_PYTHON_BIN.
attempt uv python install --default "$PYTHON_VERSION"

step "Installing global Python tools"
for tool in ruff pyright pre-commit; do
  attempt uv tool install --upgrade "$tool"
done
attempt uv tool update-shell

step "Turning on pre-commit hooks for new clones"
# Every repo cloned or created from now on installs its pre-commit hooks
# automatically if it has a .pre-commit-config.yaml (and does nothing if not).
HOOK_TEMPLATE="$HOME/.git-template"
# --type=path expands a leading ~, so "~/.git-template/" matches too.
# --get-all, because with several values --get returns the last one and the
# write below would then fail.
current_template="$(git config --global --type=path --get-all init.templateDir || true)"
if [[ -n "${GIT_TEMPLATE_DIR:-}" ]]; then
  # It overrides init.templateDir, so setting that would have no effect.
  note "GIT_TEMPLATE_DIR is set to $GIT_TEMPLATE_DIR, which overrides git's init.templateDir, so leaving it alone."
  echo "Run 'pre-commit install' in each repo to turn its hooks on."
elif [[ "$current_template" == *$'\n'* ]]; then
  note "git init.templateDir has several values in your global config, so leaving it alone."
  echo "Run 'pre-commit install' in each repo to turn its hooks on."
elif [[ -z "$current_template" || "${current_template%/}" == "$HOOK_TEMPLATE" ]]; then
  # A templateDir replaces git's default template, so start from a copy of
  # it (info/exclude, sample hooks). Copy once, so later edits are kept.
  default_template="$(git --exec-path)/../../share/git-core/templates"
  if [[ ! -e "$HOOK_TEMPLATE/info/exclude" ]]; then
    mkdir -p "$HOOK_TEMPLATE/info"
    if [[ -d "$default_template" ]]; then
      cp -R "$default_template/." "$HOOK_TEMPLATE/"
    else
      # Still give new repos an info/exclude to edit.
      : > "$HOOK_TEMPLATE/info/exclude"
      note "Couldn't find git's default template at $default_template, so new repos get an empty .git/info/exclude and no sample hooks."
    fi
  fi
  git config --global init.templateDir "$HOOK_TEMPLATE"
  # Don't hide this command's output: attempt's ✗ line goes to stdout too.
  failed_before=${#FAILED[@]}
  attempt pre-commit init-templatedir "$HOOK_TEMPLATE"
  if (( ${#FAILED[@]} == failed_before )); then
    ok "New clones will install their pre-commit hooks automatically."
  fi
else
  note "git init.templateDir is already $current_template, so leaving it alone."
  echo "Run 'pre-commit install' in each repo to turn its hooks on."
fi

step "Installing Node LTS with fnm"
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --shell bash)"
  attempt fnm install --lts
  attempt fnm default lts-latest
else
  bad "fnm isn't installed, so Node can't be either."
  FAILED+=("fnm install --lts")
fi
# Single quotes are intended: this line is written to .zshrc unexpanded.
# shellcheck disable=SC2016
FNM_INIT='eval "$(fnm env --use-on-cd --shell zsh)"'
# Any fnm env not behind a # counts; a commented-out one doesn't.
if ! grep -q '^[^#]*fnm env' "$ZSHRC" 2>/dev/null; then
  printf '\n# fnm: Node version manager (switches on cd via .nvmrc/.node-version)\n%s\n' "$FNM_INIT" >> "$ZSHRC"
  ok "Added fnm to $(tildify "$ZSHRC")"
fi

step "Putting uv's Python ahead of the system Python"
# uv adds its folders (usually just ~/.local/bin) to PATH in .zshenv, but
# macOS's /etc/zprofile then moves /usr/bin ahead of them, and .zprofile's
# brew shellenv adds /opt/homebrew/bin, so python3 would be the old system
# Python and a Homebrew ruff or pre-commit would win. .zshrc runs after
# both, so move them to the front there. The zsh line drops any existing
# copy first, so nested shells (tmux, VS Code terminals, exec zsh) don't
# pile up duplicates. A folder under $HOME is written as "$HOME/...", which
# keeps the default line the same as earlier versions of this script wrote.
zsh_path_expr() {
  case "$1" in
    "$HOME"/*) printf '%s' "\$HOME${1#"$HOME"}" ;;
    *) printf '%s' "$1" ;;
  esac
}
py_bin_expr="$(zsh_path_expr "$UV_PYTHON_BIN")"
tool_bin_expr="$(zsh_path_expr "$UV_TOOL_BIN")"
if [[ "$py_bin_expr" == "$tool_bin_expr" ]]; then
  LOCAL_BIN_INIT="path=(\"$py_bin_expr\" \${path:#$py_bin_expr})"
  added_bins="$(tildify "$UV_PYTHON_BIN")"
else
  LOCAL_BIN_INIT="path=(\"$py_bin_expr\" \"$tool_bin_expr\" \${\${path:#$py_bin_expr}:#$tool_bin_expr})"
  added_bins="$(tildify "$UV_PYTHON_BIN") and $(tildify "$UV_TOOL_BIN")"
fi
# Match the whole line, so a commented-out copy doesn't count.
if ! grep -qxF "$LOCAL_BIN_INIT" "$ZSHRC" 2>/dev/null; then
  printf '\n# uv: keep its python3 and tools ahead of the system ones\n%s\n' "$LOCAL_BIN_INIT" >> "$ZSHRC"
  ok "Added $added_bins to the front of PATH in $(tildify "$ZSHRC")"
fi

step "Verifying commands are on PATH"
# brew bundle reports "Using" for a cask whose install was interrupted,
# so check the commands themselves. Docker Desktop puts its CLI in
# ~/.docker/bin or /usr/local/bin. Append, so stale Intel-era binaries in
# /usr/local/bin don't mask a missing Homebrew install.
export PATH="$PATH:$HOME/.docker/bin:/usr/local/bin"
missing=()
col=0
for cmd in git gh rg fd jq uv gitleaks code claude docker ruff pyright pre-commit fnm node npm npx pnpm; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '  %s✓%s %-11s' "$GREEN" "$RESET" "$cmd"
  else
    printf '  %s✗ %-11s%s' "$RED" "$cmd" "$RESET"
    missing+=("$cmd")
  fi
  col=$((col + 1))
  (( col % 5 )) || printf '\n'
done
(( col % 5 == 0 )) || printf '\n'
# python3 must be uv's $PYTHON_VERSION (3.12 matches 3.12.x), not the
# system Python. PYTHON_VERSION can be any uv request (3.13t, cpython@3.12),
# so if it isn't a plain version, ask uv which version it means.
py_print_version='import platform; print(platform.python_version())'
py_version="$("$UV_PYTHON_BIN/python3" -c "$py_print_version" 2>/dev/null || true)"
py_expected="$PYTHON_VERSION"
if [[ -n "$py_version" && "$py_version" != "$PYTHON_VERSION" && "$py_version" != "$PYTHON_VERSION".* ]]; then
  py_found="$(uv python find --managed-python "$PYTHON_VERSION" 2>/dev/null || true)"
  [[ -n "$py_found" ]] && py_expected="$("$py_found" -c "$py_print_version" 2>/dev/null || true)"
fi
if [[ -z "$py_version" || ( "$py_version" != "$py_expected" && "$py_version" != "$py_expected".* ) ]]; then
  printf '  %s✗ python3 (%s from uv)%s\n' "$RED" "$PYTHON_VERSION" "$RESET"
  missing+=("python3 ($PYTHON_VERSION from uv)")
else
  printf '  %s✓%s python3 %s (uv)\n' "$GREEN" "$RESET" "$py_version"
fi
if (( ${#missing[@]} )); then
  bad "Missing: ${missing[*]}"
  echo "If docker is missing, open Docker.app once, then open a new terminal."
  echo "Otherwise, for a cask, try: brew reinstall --cask <name>"
else
  ok "All Core commands found."
fi

step "Checking FileVault"
# FileVault must be on, so Off or unknown fails the run. CI runners can't
# turn it on, so CI sets SKIP_FILEVAULT_CHECK=1 to report it without failing.
filevault_ok=1
filevault="$(fdesetup status 2>/dev/null || true)"
case "$filevault" in
  "FileVault is On."*) ok "$filevault" ;;
  "") bad "Couldn't read FileVault status. Check System Settings > Privacy & Security > FileVault."; filevault_ok=0 ;;
  *) bad "$filevault"; filevault_ok=0 ;;
esac
if (( ! filevault_ok )) && [[ -n "${SKIP_FILEVAULT_CHECK:-}" ]]; then
  note "Not failing the run for this, because SKIP_FILEVAULT_CHECK is set."
  filevault_ok=1
fi

# Not a step, so the counter skips it. Green if everything's in place.
if (( ${#FAILED[@]} )); then
  printf '\n'
  bad "These commands failed (scroll up for their errors):"
  printf '    %s\n' "${FAILED[@]}"
  echo "Fix them, then re-run ./bootstrap.sh. It's safe to re-run."
fi
if (( ${#missing[@]} || ${#FAILED[@]} || ! filevault_ok )); then done_colour="$RED"; else done_colour="$GREEN"; fi
printf '\n%s==> Done. Next manual steps:%s\n' "$BOLD$done_colour" "$RESET"
cat <<'EOF'
  1. Open a new terminal so PATH changes apply.
  2. gh auth login --hostname <ghe-host>   (see README > Install > Steps)
  3. claude   (sign in to Claude Code)
  4. If FileVault is Off: System Settings > Privacy & Security > FileVault
  5. In repos you cloned before today, run: pre-commit install
EOF

# Fail last, so one missing tool or failed install doesn't hide the rest of
# the report. The report above already says what went wrong.
EXPLAINED=1
(( ${#missing[@]} == 0 && ${#FAILED[@]} == 0 && filevault_ok ))
