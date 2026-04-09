#!/usr/bin/env bash
set -euo pipefail

# Check deployment status of commits in a pending deploy branch.
#
# This script verifies that all commits in a pending deploy branch
# have been deployed to managed-service by checking their commit trailers
# against the latest release tag.
#
# Required environment variables:
#   GITHUB_HEAD_REF: The head branch name
#   MANAGED_SERVICE_TOKEN: GitHub token with managed-service read access
#   GITHUB_OUTPUT: Path to GitHub Actions output file
#
# Outputs:
#   Sets has_issues=true/false in GITHUB_OUTPUT
#   Creates result files: not_deployed.txt, missing_trailer.txt, unexpected_status.txt

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source helper functions
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/release-helpers.sh"

# Get commits that are in the pending deploy branch but not in main
get_commits() {
  local branch="$1"

  log_info "Getting commits from $branch not in main"

  # Get commits that are in the pending deploy branch but not in main
  # Format: SHA|subject
  git log origin/main..origin/"$branch" --format="%H|%s" > commits.txt

  if [[ ! -s commits.txt ]]; then
    log_info "No commits found in $branch that are not in main"
    echo "has_issues=false" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  log_info "Commits to check:"
  cat commits.txt >&2
}

# Check deployment status of all commits
check_all_commits() {
  local latest_tag="$1"

  touch not_deployed.txt
  touch missing_trailer.txt
  touch unexpected_status.txt

  # Process each commit
  while IFS='|' read -r sha subject; do
    log_info "Checking commit $sha: $subject"

    # Extract managed-service commit SHA from git commit message trailer
    local ms_sha
    ms_sha=$(git log -1 --format='%(trailers:key=Managed-service-commit-SHA,valueonly)' "$sha")

    if [[ -z "$ms_sha" ]]; then
      log_info "  No Managed-service-commit-SHA trailer found"
      echo "$sha|$subject" >> missing_trailer.txt
      continue
    fi

    log_info "  Found managed-service SHA: $ms_sha"

    # Check deployment status
    local output
    output=$(check_deployment_status "$ms_sha" "$latest_tag")
    local status=$?

    if [[ $status -eq 0 ]]; then
      log_info "  Deployed"
    elif [[ $status -eq 1 ]]; then
      log_info "  Not deployed yet"
      echo "$sha|$subject|$ms_sha" >> not_deployed.txt
    else
      log_error "  Unexpected status: $output"
      echo "$sha|$subject|$ms_sha|$output" >> unexpected_status.txt
    fi
  done < commits.txt
}

# Check results and set output
check_results() {
  if [[ -s not_deployed.txt ]] || [[ -s missing_trailer.txt ]] || [[ -s unexpected_status.txt ]]; then
    log_error "Found commits that are not deployed or potentially not deployed"
    echo "has_issues=true" >> "$GITHUB_OUTPUT"
  else
    log_info "All commits are deployed"
    echo "has_issues=false" >> "$GITHUB_OUTPUT"
  fi
}

# Main execution
main() {
  log_info "=== Starting pending deploy check ==="

  if [[ -z "${GITHUB_HEAD_REF:-}" ]]; then
    log_error "GITHUB_HEAD_REF environment variable is not set"
    exit 1
  fi

  if [[ -z "${MANAGED_SERVICE_TOKEN:-}" ]]; then
    log_error "MANAGED_SERVICE_TOKEN environment variable is not set"
    exit 1
  fi

  if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
    log_error "GITHUB_OUTPUT environment variable is not set"
    exit 1
  fi

  get_commits "$GITHUB_HEAD_REF"

  if ! get_latest_release_tag; then
    exit 1
  fi

  check_all_commits "$LATEST_RELEASE_TAG"

  check_results

  log_info "=== Pending deploy check completed ==="
}

main
