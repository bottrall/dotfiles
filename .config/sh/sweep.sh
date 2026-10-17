# sweep — reset the local dev environment to a clean baseline.
#
# Sourced by .zshrc/.bashrc. The function body is a subshell, so pipefail,
# helper functions, and nvm sourcing don't leak into the interactive shell.
#
# Iterates the repos listed by repos() (see repos.sh / ~/.repos.local).
# First checks the C toolchain can build a test program; if it can't (e.g.
# Xcode lagging a macOS upgrade), brew upgrade, AUR upgrades and bundle install
# are skipped.
# For each repo:
#   - git fetch --prune + git worktree prune
#   - switch to the default branch and pull (skipped if the tree is dirty)
#   - delete local branches that aren't the default or checked out in a worktree
#   - bundle install / pnpm install if the repo uses them
#   - git maintenance run
#   - record the node/ruby versions the repo (and its worktrees) pin
# Then:
#   - brew update / upgrade / autoremove / cleanup (macOS)
#   - pacman/paru -Syu, remove orphans, prune package and AUR build caches,
#     flag unmerged .pacnew/.pacsave files (Arch; prompts for sudo)
#   - uninstall nvm node versions and rbenv rubies no repo needs
#   - pnpm store prune, nvm cache clear, gem cleanup on kept rubies
#   - docker system prune (volumes and tagged images untouched)
# Failed or skipped steps are listed in the summary, and sweep exits non-zero.
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

  # like warn, but also listed in the summary and makes sweep exit non-zero
  FAILURES=()
  fail() { warn "$*"; FAILURES+=("$*"); }

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

  # --- toolchain -----------------------------------------------------------------

  # Building from source (brew, AUR, native gems) fails when the compiler can't link,
  # e.g. an Xcode older than the macOS SDK. Check up front instead of failing
  # halfway through an upgrade.
  cc_works() {
    local tmp rc
    # on macOS, invoking the /usr/bin/cc shim without developer tools pops an
    # install dialog
    if [[ "$(uname)" == "Darwin" ]]; then
      xcode-select -p >/dev/null 2>&1 || return 1
    fi
    command -v cc >/dev/null || return 1
    tmp=$(mktemp -d) || return 1
    printf 'int main(void) { return 0; }\n' | command cc -x c - -o "$tmp/a.out" >/dev/null 2>&1
    rc=$?
    rm -rf "$tmp"
    return $rc
  }

  say "toolchain"
  if cc_works; then
    TOOLCHAIN_OK=1
    note "cc ok"
  else
    TOOLCHAIN_OK=0
    fail "cc can't build a test program — skipping brew upgrade, AUR upgrades and bundle install"
    if [[ "$(uname)" == "Darwin" ]]; then
      note "developer dir: $(xcode-select -p 2>/dev/null || echo none)"
      note "update Xcode to match macOS, or: sudo xcode-select -s /Library/Developer/CommandLineTools"
    fi
  fi

  # --- homebrew ----------------------------------------------------------------

  if command -v brew >/dev/null; then
    say "homebrew"
    run brew update || fail "brew update failed"
    if (( TOOLCHAIN_OK )); then
      run brew upgrade || fail "brew upgrade failed"
    else
      note "brew upgrade skipped (toolchain)"
    fi
    run brew autoremove || fail "brew autoremove failed"
    run brew cleanup --prune=all || fail "brew cleanup failed"
  fi

  # --- pacman / paru -------------------------------------------------------------

  # Arch doesn't support partial upgrades, so repo packages always upgrade and
  # the toolchain only gates AUR builds. Upgrades stay interactive (no
  # --noconfirm) so paru can show PKGBUILD diffs for review.
  clean_pacman() {
    say "pacman"
    if (( ! DRY_RUN )) && ! sudo -v; then
      fail "sudo unavailable — pacman skipped"
      return 1
    fi

    if (( TOOLCHAIN_OK )) && command -v paru >/dev/null; then
      run paru -Syu || fail "paru -Syu failed"
    else
      (( TOOLCHAIN_OK )) || note "AUR upgrades skipped (toolchain)"
      run sudo pacman -Syu || fail "pacman -Syu failed"
    fi

    # dependencies nothing requires any more (brew autoremove)
    local orphans=() p
    while IFS= read -r p; do orphans+=("$p"); done < <(pacman -Qdtq)
    if (( ${#orphans[@]} )); then
      run sudo pacman -Rns --noconfirm "${orphans[@]}" || fail "orphan removal failed"
      SUMMARY+=("pacman: removed orphans ${orphans[*]}")
    fi

    # keep the two newest versions of installed packages for rollback, none of
    # uninstalled ones
    if command -v paccache >/dev/null; then
      run sudo paccache -rk2 || fail "paccache failed"
      run sudo paccache -ruk0 || fail "paccache failed"
    else
      warn "paccache not found (install pacman-contrib) — package cache left as is"
    fi

    # partial downloads left behind by interrupted syncs
    if [[ ! -e /var/lib/pacman/db.lck ]]; then
      run sudo find /var/cache/pacman/pkg -mindepth 1 -maxdepth 1 -type d -name 'download-*' -exec rm -rf {} +
    fi

    # paru keeps a git clone per AUR package base. Drop clones of packages no
    # longer installed, and build leftovers (sources, built packages) from the
    # rest — the git history stays so paru can still diff PKGBUILDs.
    local clone_dir="${XDG_CACHE_HOME:-$HOME/.cache}/paru/clone" foreign=() d name keep
    if [[ -d "$clone_dir" ]]; then
      while IFS= read -r p; do foreign+=("$p"); done < <(pacman -Qmq)
      while IFS= read -r d; do
        keep=0
        # a split package's clone is named after its base, so check every pkgname
        while IFS= read -r name; do
          contains "$name" "${foreign[@]}" && keep=1
        done < <(basename "$d"; sed -n 's/^[[:space:]]*pkgname = //p' "$d/.SRCINFO" 2>/dev/null)
        if (( keep )); then
          run git -C "$d" clean -ffdxq || fail "paru: git clean failed in $d"
        else
          run rm -rf "$d"
          SUMMARY+=("paru: removed clone $(basename "$d")")
        fi
      done < <(find "$clone_dir" -mindepth 1 -maxdepth 1 -type d)
    fi

    local pacnew
    pacnew=$(find /etc \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null)
    if [[ -n "$pacnew" ]]; then
      warn "unmerged config files — review with: sudo DIFFPROG='nvim -d' pacdiff"
      while IFS= read -r p; do note "$p"; done <<< "$pacnew"
      SUMMARY+=("pacman: $(wc -l <<< "$pacnew" | tr -d ' ') unmerged .pacnew/.pacsave file(s)")
    fi
  }

  command -v pacman >/dev/null && clean_pacman

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

    git -C "$repo" fetch --prune --quiet origin || fail "$repo: fetch failed"
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
      run git -C "$repo" switch --quiet "$default" || { fail "$repo: could not switch to $default"; return 1; }
    fi
    run git -C "$repo" pull --ff-only --quiet origin "$default" || fail "$repo: pull failed"

    local deleted=0 ahead
    while IFS= read -r b; do
      [[ "$b" == "$default" ]] && continue
      contains "$b" "${wt_branches[@]}" && continue
      ahead=$(git -C "$repo" rev-list --count "origin/$default..$b" 2>/dev/null || echo "?")
      [[ "$ahead" != "0" ]] && warn "$b has $ahead commits not on origin/$default"
      run git -C "$repo" branch -D "$b" && deleted=$((deleted + 1))
    done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads)

    if [[ -f "$repo/Gemfile.lock" || -f "$repo/Gemfile" ]] && command -v bundle >/dev/null; then
      if (cd "$repo" && bundle check >/dev/null 2>&1); then
        :
      elif (( TOOLCHAIN_OK )); then
        run bash -c "cd '$repo' && bundle install" || fail "$repo: bundle install failed"
      else
        fail "$repo: bundle install skipped (toolchain)"
      fi
    fi
    if [[ -f "$repo/pnpm-lock.yaml" ]] && command -v pnpm >/dev/null; then
      run bash -c "cd '$repo' && pnpm install --frozen-lockfile --prefer-offline" || fail "$repo: pnpm install failed"
    fi

    run git -C "$repo" maintenance run --quiet || fail "$repo: git maintenance failed"

    SUMMARY+=("$repo: on $default, $deleted branch(es) deleted")
  }

  for repo in "${REPOS[@]}"; do
    clean_repo "$repo"
  done

  # --- node versions (nvm) ---------------------------------------------------------

  NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
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
  # whole-volume free space, so anything else writing during the run counts too
  FREED_MB=$(( ($(disk_free_kb) - FREE_BEFORE) / 1024 ))
  if (( FREED_MB >= 0 )); then
    note "disk freed: $FREED_MB MB"
  else
    note "disk freed: none (free space fell $(( -FREED_MB )) MB during the run)"
  fi

  if (( ${#FAILURES[@]} )); then
    say "failures"
    for line in "${FAILURES[@]}"; do
      warn "$line"
    done
    exit 1
  fi
)
