wta() {
  if [[ -z "$1" ]]; then
    echo "Usage: wta <branch_name>"
    return 1
  fi

  local branch="$1"

  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local main_worktree
  main_worktree=$(git worktree list --porcelain | head -1 | sed 's/worktree //')

  local project_name
  project_name=$(basename "$main_worktree")

  local worktree_path
  worktree_path="$(dirname "$main_worktree")/${project_name}.worktrees/${branch}"

  local default_branch
  default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
  if [[ -z "$default_branch" ]]; then
    if git show-ref --verify --quiet refs/remotes/origin/main; then
      default_branch="main"
    else
      default_branch="master"
    fi
  fi

  if git show-ref --verify --quiet "refs/heads/${branch}" || \
     git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    git worktree add "$worktree_path" "$branch"
  else
    git worktree add -b "$branch" "$worktree_path" "origin/${default_branch}"
  fi

  if [[ $? -eq 0 ]]; then
    cd "$worktree_path"
  fi
}

wtd() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi

  local current_path
  current_path=$(pwd)

  local main_worktree
  main_worktree=$(git worktree list --porcelain | head -1 | sed 's/worktree //')

  if [[ "$current_path" == "$main_worktree" ]]; then
    echo "Error: Cannot remove the main worktree. Run this from a secondary worktree."
    return 1
  fi

  local branch
  branch=$(git branch --show-current)

  if [[ -z "$branch" ]]; then
    echo "Error: Could not determine current branch"
    return 1
  fi

  cd "$main_worktree"

  git worktree remove --force "$current_path"

  if [[ $? -eq 0 ]]; then
    git branch -D "$branch"
    echo "Removed worktree and branch: $branch"
  else
    echo "Error: Failed to remove worktree"
    return 1
  fi
}
