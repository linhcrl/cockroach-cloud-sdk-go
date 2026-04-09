#!/usr/bin/env bash
# Shared utility functions for pending deploy workflows

# Get the latest managed-service release tag
# Exports: LATEST_RELEASE_TAG
# Returns: 0 on success, 1 on failure
get_latest_release_tag() {
  if [[ -z "${MANAGED_SERVICE_TOKEN:-}" ]]; then
    log_error "MANAGED_SERVICE_TOKEN environment variable is not set"
    return 1
  fi

  export GH_TOKEN="$MANAGED_SERVICE_TOKEN"

  log_info "Fetching release tags from managed-service repository"

  # Fetch all release tags matching release-YYYY-MM-DD-N pattern
  # The GitHub API returns results in pages (30 items per page). Without --paginate, we'd only get
  # the first page. With --paginate, gh automatically fetches all pages for us. We need all tags
  # because the API doesn't support sorting by date, so we must fetch everything and sort ourselves.
  local all_tags
  all_tags=$(gh api repos/cockroachlabs/managed-service/tags --paginate --jq '.[].name' | grep -E '^release-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]+$')

  if [[ -z "${all_tags:-}" ]]; then
    log_error "No release tags found in managed-service repository"
    return 1
  fi

  # Sort and get the latest (tags sort lexicographically in chronological order)
  LATEST_RELEASE_TAG=$(echo "$all_tags" | sort -r | head -1)

  log_info "Latest release tag: $LATEST_RELEASE_TAG"
  export LATEST_RELEASE_TAG
  return 0
}

# Check if a managed-service commit SHA is deployed in the latest release
# Args: $1 - managed-service commit SHA
#       $2 - latest release tag
# Returns: 0 if deployed, 1 if not deployed, 2 if unexpected status
check_deployment_status() {
  local ms_sha="$1"
  local latest_tag="$2"

  if [[ -z "${ms_sha:-}" || -z "${latest_tag:-}" ]]; then
    log_error "Both ms_sha and latest_tag are required"
    echo "missing_parameters"
    return 2
  fi

  if [[ -z "${MANAGED_SERVICE_TOKEN:-}" ]]; then
    log_error "MANAGED_SERVICE_TOKEN environment variable is not set"
    echo "missing_token"
    return 2
  fi

  export GH_TOKEN="$MANAGED_SERVICE_TOKEN"

  log_info "Comparing $ms_sha against latest release tag: $latest_tag"

  # Compare the latest release tag with the commit SHA
  # Status can be: identical, ahead, behind, or diverged
  local compare_status
  if ! compare_status=$(gh api "repos/cockroachlabs/managed-service/compare/${latest_tag}...${ms_sha}" --jq '.status' 2>&1); then
    log_error "Failed to compare commit with release tag: $compare_status"
    echo "unknown"
    return 2
  fi

  log_info "Comparison status: $compare_status"

  case "$compare_status" in
    identical|behind)
      # SHA has been deployed
      log_info "Status: Deployed"
      return 0
      ;;
    ahead)
      # SHA is ahead of the latest release - not deployed yet
      log_info "Status: Not deployed (ahead of $latest_tag)"
      return 1
      ;;
    *)
      # Unexpected status (e.g., diverged or other)
      echo "$compare_status"
      log_error "Unexpected comparison status: $compare_status"
      return 2
      ;;
  esac
}
