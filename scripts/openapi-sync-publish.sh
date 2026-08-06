#!/usr/bin/env bash
set -euo pipefail

# Publish OpenAPI sync changes.
#
# This script:
# 1. Commits changes with generated metadata
# 2. Pushes to fork
# 3. Creates or updates SDK PR
# 4. Rebase-merges the SDK PR into its pending deploy branch (merged events only)
#
# Environment variables:
#   EVENT_TYPE: Type of event triggering the sync (openapi-spec-changed or openapi-spec-merged)
#   MANAGED_SERVICE_PR_URL: URL of the managed-service PR containing spec changes
#   MANAGED_SERVICE_SHA: Commit SHA in managed-service (merged events only)
#   FORK_OWNER: GitHub username of the bot fork owner
#   FORK_PUSH_TOKEN: GitHub token with push access to bot fork (secret)
#   GH_TOKEN: GitHub token for gh CLI operations (secret)
#   GITHUB_REPOSITORY: Current repository in owner/repo format
#   BASE_BRANCH: Base branch for the SDK PR
#   HAS_CHANGES: Whether there are changes to commit
#   EXISTING_SDK_PR: Whether updating existing PR or creating new one
#   HEAD_BRANCH: Head branch name for the SDK PR
#   SDK_PR_NUMBER: SDK PR number (when updating existing PR)
#   COMMIT_TITLE: Generated commit title (when there are changes)
#   COMMIT_BODY: Generated commit body (when there are changes)
#   PR_TITLE: Generated PR title (when there are changes)
#   PR_DESCRIPTION: Generated PR description (when there are changes)
#   AUTOMERGE_FAILURE_REVIEWERS: Comma-separated handles to request review from on automerge failure

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "$SCRIPT_DIR/lib/actions-helpers.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/openapi-sync-helpers.sh"

# Main execution
main() {
  log_info "=== Starting OpenAPI sync step: Publish ==="

  check_required_commands "gh" "git" || exit 1
  check_required_env "EVENT_TYPE" "MANAGED_SERVICE_PR_URL" "FORK_OWNER" \
    "FORK_PUSH_TOKEN" "GH_TOKEN" "GITHUB_REPOSITORY" "BASE_BRANCH" \
    "HAS_CHANGES" "EXISTING_SDK_PR" "HEAD_BRANCH" || exit 1
  commit_changes
  push_to_fork
  create_or_update_pr

  if [[ "$HAS_CHANGES" == "false" && "$EVENT_TYPE" != "openapi-spec-merged" ]]; then
    log_info "No changes detected after syncing OpenAPI spec and regenerating client"
  fi

  # Not guarded on HAS_CHANGES: a merged event whose spec is unchanged still amends the commit
  # to add the Managed-service-commit-SHA trailer, and that trailer has to reach the base branch.
  if [[ "$EVENT_TYPE" == "openapi-spec-merged" ]]; then
    automerge_sdk_pr || exit 1
  fi

  log_info "=== OpenAPI sync step completed: Publish ==="
}

main
