#!/usr/bin/env bash
set -euo pipefail

# Create or update a PR for the latest pending deploy branch.
#
# This script finds the latest pending deploy branch and creates a PR
# to merge it into main if it has commits that are not yet in main.
#
# Required environment variables:
#   GITHUB_TOKEN: GitHub token for creating PRs
#   GITHUB_REPOSITORY: Repository in owner/repo format
#   GITHUB_OUTPUT: Path to GitHub Actions output file

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "$SCRIPT_DIR/lib/logging.sh"

# Find the latest pending deploy branch
find_latest_branch() {
  log_info "Looking for pending deploy branches"

  # Find all remote branches matching pending-deploy-YYYYMMDD-HHMMSS
  local all_branches
  all_branches=$(git branch -r)

  local branches
  branches=$(echo "$all_branches" | grep -E 'origin/pending-deploy-[0-9]{8}-[0-9]{6}$' || true)

  if [[ -z "$branches" ]]; then
    log_info "No pending deploy branches found on origin"
    echo "branch=" >> "$GITHUB_OUTPUT"
    return 0
  fi

  # Find the latest branch (branches sort lexicographically in chronological order)
  local latest
  latest=$(echo "$branches" | sed 's|^[[:space:]]*origin/||' | sort -r | head -1)

  if [[ -z "$latest" ]]; then
    log_error "Failed to parse pending deploy branches"
    exit 1
  fi

  log_info "Latest pending deploy branch: $latest"
  echo "branch=$latest" >> "$GITHUB_OUTPUT"
  export BRANCH="$latest"
}

# Check if the branch has commits not in main
check_commits() {
  local branch="$1"

  if [[ -z "$branch" ]]; then
    return 0
  fi

  log_info "Checking for commits in $branch not in main"

  # Count commits in branch but not in origin/main
  local commit_count
  commit_count=$(git rev-list --count origin/main..origin/"$branch")

  if [[ "$commit_count" -eq 0 ]]; then
    log_info "No new commits in $branch"
    echo "has_commits=false" >> "$GITHUB_OUTPUT"
    return 0
  fi

  log_info "Found $commit_count commit(s) in $branch not in main"
  echo "has_commits=true" >> "$GITHUB_OUTPUT"
  export HAS_COMMITS="true"
}

# Create or check for existing PR
create_or_check_pr() {
  local branch="$1"

  if [[ -z "$branch" ]] || [[ "${HAS_COMMITS:-false}" != "true" ]]; then
    return 0
  fi

  export GH_TOKEN="$GITHUB_TOKEN"

  log_info "Checking if PR already exists for $branch"

  # Check if PR already exists
  local existing_pr
  existing_pr=$(gh pr list --head "$branch" --base main --json number --jq '.[0].number' || echo "")

  if [[ -n "$existing_pr" ]]; then
    log_info "PR already exists: #$existing_pr"
    return 0
  fi

  log_info "Creating new PR for $branch"

  # Create new PR
  local pr_body
  pr_body=$(printf "%s\n\n%s" \
    "This PR represents commits from \`$branch\` that are pending deployment. These commits were generated in response to Cockroach Cloud API changes in the managed-service repository." \
    "This PR is automatically managed by the pending-deploy-pr workflow.")

  local pr_url
  pr_url=$(gh pr create \
    --head "$branch" \
    --base main \
    --title "Applying pending deploy changes: $branch" \
    --body "$pr_body")

  if [[ -z "$pr_url" ]]; then
    log_error "Failed to create PR"
    exit 1
  fi

  log_info "Created PR: $pr_url"
  echo "pr_url=$pr_url" >> "$GITHUB_OUTPUT"
}

# Main execution
main() {
  log_info "=== Starting pending deploy PR workflow ==="

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    log_error "GITHUB_TOKEN environment variable is not set"
    exit 1
  fi

  if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
    log_error "GITHUB_REPOSITORY environment variable is not set"
    exit 1
  fi

  if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
    log_error "GITHUB_OUTPUT environment variable is not set"
    exit 1
  fi

  find_latest_branch

  if [[ -n "${BRANCH:-}" ]]; then
    check_commits "$BRANCH"
    create_or_check_pr "$BRANCH"
  fi

  log_info "=== Pending deploy PR workflow completed ==="
}

main
