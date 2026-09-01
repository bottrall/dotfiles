# sweep — reset the local dev environment to a clean baseline.
#
# Sourced by .zshrc/.bashrc. The function body is a subshell, so pipefail,
# helper functions, and nvm sourcing don't leak into the interactive shell.
#
# Iterates the repos listed by repos() (see repos.sh / ~/.repos.local).
# For each repo:
#   - git fetch --prune + git worktree prune
#   - switch to the default branch and pull (skipped if the tree is dirty)
#   - delete local branches that aren't the default or checked out in a worktree
#   - bundle install / pnpm install if the repo uses them
#   - git maintenance run
#   - record the node/ruby versions the repo (and its worktrees) pin
# Then:
#   - brew update / upgrade / autoremove / cleanup
#   - uninstall nvm node versions and rbenv rubies no repo needs
#   - pnpm store prune, nvm cache clear, gem cleanup on kept rubies
#   - docker system prune (volumes and tagged images untouched)
#
# Usage: sweep [-n|--dry-run]
#   --dry-run: fetch and report, but make no changes.

sweep() (
  set -o pipefail

  DRY_RUN=0
  case "${1:-}" in
    -n|--dry-run) DRY_RUN=1 ;;
    "") ;;
    *) echo "Usage: sweep [-n|--dry-run]" >&2; exit 2 ;;
  esac

  say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
  note() { printf '    %s\n' "$*"; }
  warn() { printf '    \033[33m%s\033[0m\n' "$*"; }

  run() {
    if (( DRY_RUN )); then
      note "[dry-run] $*"
    else
      "$@"
    fi
  }

  contains() {
    local x="$1" i
    shift
    for i in "$@"; do [[ "$i" == "$x" ]] && return 0; done
    return 1
  }

  # --- repo list ---------------------------------------------------------------

  if ! command -v repos >/dev/null; then
    echo "repos() not found — is ~/.config/sh/repos.sh sourced?" >&2
    exit 1
  fi

  repo_list=$(repos) || exit 1
  if [[ -z "$repo_list" ]]; then
    echo "Project list is empty" >&2
    exit 1
  fi
  REPOS=()
  while IFS= read -r line; do REPOS+=("$line"); done <<< "$repo_list"

  NODE_SPECS=()
  RUBY_SPECS=()
  SUMMARY=()

  disk_free_kb() { df -k "$HOME" | awk 'NR==2 {print $4}'; }
  FREE_BEFORE=$(disk_free_kb)

  # --- homebrew ----------------------------------------------------------------

  if command -v brew >/dev/null; then
    say "homebrew"
    run brew update
    run brew upgrade
    run brew autoremove
    run brew cleanup --prune=all
  fi

  # --- per-repo version pins -----------------------------------------------------

  collect_versions() {
    local dir="$1" f spec
    for f in .nvmrc .node-version; do
      if [[ -f "$dir/$f" ]]; then
        spec="$(tr -d '[:space:]' < "$dir/$f")"
        [[ -n "$spec" ]] && NODE_SPECS+=("$spec")
      fi
    done
    if [[ -f "$dir/.ruby-version" ]]; then
      spec="$(tr -d '[:space:]' < "$dir/.ruby-version")"
      spec="${spec#ruby-}"
      [[ -n "$spec" ]] && RUBY_SPECS+=("$spec")
    fi
  }

  # --- per-repo cleanup ----------------------------------------------------------

  clean_repo() {
    local repo="$1"
    say "$repo"

    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
      warn "not a git repo — skipped"
      SUMMARY+=("$repo: skipped (not a git repo)")
      return 1
    fi

    git -C "$repo" fetch --prune --quiet origin || warn "fetch failed"
    run git -C "$repo" worktree prune

    local default
    default=$(git -C "$repo" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [[ -z "$default" ]]; then
      if git -C "$repo" show-ref --verify --quiet refs/remotes/origin/main; then
        default="main"
      else
        default="master"
      fi
    fi

    # Branches checked out in any worktree (including the main one) are off-limits,
    # and every worktree's version pins count as still needed.
    local wt_branches=() wt_paths=() p b
    while IFS= read -r p; do wt_paths+=("$p"); done \
      < <(git -C "$repo" worktree list --porcelain | sed -n 's/^worktree //p')
    while IFS= read -r b; do wt_branches+=("$b"); done \
      < <(git -C "$repo" worktree list --porcelain | sed -n 's|^branch refs/heads/||p')

    for p in "${wt_paths[@]}"; do
      collect_versions "$p"
    done

    if [[ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]]; then
      warn "working tree is dirty — left untouched (versions still recorded)"
      SUMMARY+=("$repo: skipped (dirty working tree)")
      return 0
    fi

    if [[ "$(git -C "$repo" branch --show-current)" != "$default" ]]; then
      run git -C "$repo" switch --quiet "$default" || { warn "could not switch to $default"; return 1; }
    fi
    run git -C "$repo" pull --ff-only --quiet origin "$default" || warn "pull failed"

    local deleted=0 ahead
    while IFS= read -r b; do
      [[ "$b" == "$default" ]] && continue
      contains "$b" "${wt_branches[@]}" && continue
      ahead=$(git -C "$repo" rev-list --count "origin/$default..$b" 2>/dev/null || echo "?")
      [[ "$ahead" != "0" ]] && warn "$b has $ahead commits not on origin/$default"
      run git -C "$repo" branch -D "$b" && deleted=$((deleted + 1))
    done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads)

    if [[ -f "$repo/Gemfile.lock" || -f "$repo/Gemfile" ]] && command -v bundle >/dev/null; then
      run bash -c "cd '$repo' && (bundle check >/dev/null 2>&1 || bundle install)" || warn "bundle install failed"
    fi
    if [[ -f "$repo/pnpm-lock.yaml" ]] && command -v pnpm >/dev/null; then
      run bash -c "cd '$repo' && pnpm install --frozen-lockfile --prefer-offline" || warn "pnpm install failed"
    fi

    run git -C "$repo" maintenance run --quiet || warn "git maintenance failed"

    SUMMARY+=("$repo: on $default, $deleted branch(es) deleted")
  }

  for repo in "${REPOS[@]}"; do
    clean_repo "$repo"
  done

  # --- node versions (nvm) ---------------------------------------------------------

  NVM_DIR="${NVM_DIR:-$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "$HOME/.nvm" || printf %s "$XDG_CONFIG_HOME/nvm")}"
  export NVM_DIR
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    say "node versions"
    . "$NVM_DIR/nvm.sh" --no-use

    NODE_KEEP=()
    v=$(nvm version default)
    [[ "$v" != "N/A" ]] && NODE_KEEP+=("$v")
    for spec in "${NODE_SPECS[@]}"; do
      v=$(nvm version "$spec")
      if [[ "$v" == "N/A" ]]; then
        warn "a repo pins node '$spec' but no installed version matches"
      else
        contains "$v" "${NODE_KEEP[@]}" || NODE_KEEP+=("$v")
      fi
    done
    note "keeping: ${NODE_KEEP[*]:-none}"

    if [[ ${#NODE_SPECS[@]} -eq 0 ]]; then
      warn "no repo pins a node version — skipping node uninstalls"
    else
      while IFS= read -r v; do
        contains "$v" "${NODE_KEEP[@]}" && continue
        run nvm uninstall "$v"
        SUMMARY+=("node $v: uninstalled")
      done < <(ls "$NVM_DIR/versions/node" 2>/dev/null)
    fi

    run nvm cache clear
  fi

  # --- ruby versions (rbenv) ---------------------------------------------------------

  if command -v rbenv >/dev/null; then
    say "ruby versions"

    RUBY_KEEP=("$(rbenv global)")
    for spec in "${RUBY_SPECS[@]}"; do
      contains "$spec" "${RUBY_KEEP[@]}" || RUBY_KEEP+=("$spec")
    done
    note "keeping: ${RUBY_KEEP[*]:-none}"

    keep_ruby() {
      local installed="$1" k
      for k in "${RUBY_KEEP[@]}"; do
        # exact match, or the pin is a prefix like "3.3" matching "3.3.10"
        [[ "$installed" == "$k" || "$installed" == "$k".* ]] && return 0
      done
      return 1
    }

    if [[ ${#RUBY_SPECS[@]} -eq 0 ]]; then
      warn "no repo pins a ruby version — skipping ruby uninstalls"
    else
      while IFS= read -r v; do
        keep_ruby "$v" && continue
        run rbenv uninstall -f "$v"
        SUMMARY+=("ruby $v: uninstalled")
      done < <(rbenv versions --bare)
    fi

    # closest thing to a store prune for ruby: drop superseded gem versions
    for v in "${RUBY_KEEP[@]}"; do
      [[ "$v" == "system" ]] && continue
      rbenv versions --bare | grep -qx "$v" || continue
      run env RBENV_VERSION="$v" rbenv exec gem cleanup
    done
  fi

  # --- caches --------------------------------------------------------------------------

  if command -v pnpm >/dev/null; then
    say "pnpm store"
    run pnpm store prune
  fi

  # stopped containers, dangling images, unused networks, build cache.
  # Volumes and tagged images are deliberately untouched.
  if command -v docker >/dev/null; then
    say "docker"
    if docker info >/dev/null 2>&1; then
      run docker system prune --force
    else
      warn "docker daemon not running — skipped"
    fi
  fi

  # --- summary -------------------------------------------------------------------------

  say "summary"
  (( DRY_RUN )) && note "(dry run — nothing was changed)"
  for line in "${SUMMARY[@]}"; do
    note "$line"
  done
  FREE_AFTER=$(disk_free_kb)
  note "disk freed: $(( (FREE_AFTER - FREE_BEFORE) / 1024 )) MB"
)
