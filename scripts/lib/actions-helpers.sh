#!/usr/bin/env bash
# Shared helpers for GitHub Actions workflows

# Output an informational message to stdout
log_info() {
  local message="$1"
  echo "$message"
}

# Output an error message using GitHub Actions workflow command format
# https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#setting-an-error-message
log_error() {
  local message="$1"
  echo "::error::$message" >&2
}

# Output a warning message using GitHub Actions workflow command format
log_warning() {
  local message="$1"
  echo "::warning::$message" >&2
}

# Output a notice message using GitHub Actions workflow command format
log_notice() {
  local message="$1"
  echo "::notice::$message"
}

# Write a single-line output: set_output key value
set_output() {
  echo "$1=$2" >> "${GITHUB_OUTPUT:-/dev/null}"
}

# Request review on a PR so it reaches a human; nobody is subscribed to a bot PR.
#
# Best-effort: callers report their own failures and the work that created the PR matters more.
#
# Args: $1 - PR number, $2 - comma-separated handles (no-op when empty)
request_pr_reviewers() {
  local pr_number="$1" reviewers="$2" args=() reviewer

  if [[ -z "$reviewers" ]]; then
    return
  fi

  # REST, not `gh pr edit --add-reviewer`: that resolves handles via GraphQL and needs `read:org`,
  # which the workflow token lacks.
  for reviewer in ${reviewers//,/ }; do
    args+=(--field "reviewers[]=$reviewer")
  done

  if gh api --method POST \
    "repos/$GITHUB_REPOSITORY/pulls/$pr_number/requested_reviewers" "${args[@]}" >/dev/null; then
    log_info "Requested review on PR #$pr_number from $reviewers"
  else
    log_warning "Could not request review on PR #$pr_number from $reviewers"
  fi
}
