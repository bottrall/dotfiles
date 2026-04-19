glazimate-next() {
  local project_id="PVT_kwDOEGXJvM4BUbLD"
  local field_id="PVTSSF_lADOEGXJvM4BUbLDzhBjW-U"
  local backlog_option_id="405af02e"
  local ready_option_id="5b7f2f3f"
  local in_progress_option_id="28af537d"
  local repo="bottralldotdev/glazimate"

  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    return 1
  fi

  # Fetch all project items with statuses and blockers in one query
  local items
  items=$(gh api graphql -f query='{
    node(id: "'"$project_id"'") {
      ... on ProjectV2 {
        items(first: 100) {
          nodes {
            id
            fieldValueByName(name: "Status") {
              ... on ProjectV2ItemFieldSingleSelectValue {
                optionId
              }
            }
            content {
              ... on Issue {
                number
                title
                blockedBy(first: 20) {
                  nodes {
                    state
                  }
                }
              }
            }
          }
        }
      }
    }
  }' --jq '.data.node.items.nodes[]
    | select(.content.number != null)
    | "\(.id)\t\(.fieldValueByName.optionId)\t\(.content.number)\t\(.content.title)\t\([(.content.blockedBy.nodes // [])[].state] | if length == 0 then "NONE" elif all(. == "CLOSED") then "CLEAR" else "BLOCKED" end)"')

  # Promote unblocked backlog items to Ready
  local promoted=0
  while IFS=$'\t' read -r item_id status_id issue_number issue_title blocker_status; do
    if [[ "$status_id" == "$backlog_option_id" && ("$blocker_status" == "CLEAR" || "$blocker_status" == "NONE") ]]; then
      gh api graphql --silent -f query='mutation {
        updateProjectV2ItemFieldValue(input: {
          projectId: "'"$project_id"'",
          itemId: "'"$item_id"'",
          fieldId: "'"$field_id"'",
          value: { singleSelectOptionId: "'"$ready_option_id"'" }
        }) { projectV2Item { id } }
      }'
      echo "Promoted to Ready: #${issue_number} — ${issue_title}"
      promoted=$((promoted + 1))
    fi
  done <<< "$items"

  if [[ $promoted -gt 0 ]]; then
    echo ""
  fi

  # Pick the first Ready item
  local result
  result=$(echo "$items" | awk -F'\t' '$2 == "'"$ready_option_id"'"' | head -1)

  # Also check freshly promoted items
  if [[ -z "$result" ]]; then
    result=$(echo "$items" | awk -F'\t' '$2 == "'"$backlog_option_id"'" && ($5 == "CLEAR" || $5 == "NONE")' | head -1)
  fi

  if [[ -z "$result" ]]; then
    echo "No issues ready to pick up."
    return 1
  fi

  local item_id issue_number issue_title
  item_id=$(echo "$result" | cut -f1)
  issue_number=$(echo "$result" | cut -f3)
  issue_title=$(echo "$result" | cut -f4)

  echo "Picking up: #${issue_number} — ${issue_title}"

  # Move to In Progress
  gh api graphql --silent -f query='mutation {
    updateProjectV2ItemFieldValue(input: {
      projectId: "'"$project_id"'",
      itemId: "'"$item_id"'",
      fieldId: "'"$field_id"'",
      value: { singleSelectOptionId: "'"$in_progress_option_id"'" }
    }) { projectV2Item { id } }
  }'

  echo "Moved to In Progress"

  local branch
  branch=$(printf '%s' "${issue_number}-${issue_title}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//' \
    | cut -c1-72)

  gh issue develop "$issue_number" --repo "$repo" --name "$branch" --base main

  git fetch origin "$branch" --quiet

  wta "$branch"

  echo "Branch: ${branch}"
  echo ""

  cc "/plan Implement ${repo}#${issue_number}"
}
