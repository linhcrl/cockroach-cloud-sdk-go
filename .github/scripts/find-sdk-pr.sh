#!/bin/bash
set -euo pipefail

# Find an SDK PR that corresponds to a managed-service PR URL.
#
# This script searches all open PRs in the current repository and inspects
# all commits in each PR to find one containing a trailer:
#   Managed-service-pr-url: <pr_url>
#
# Usage:
#   find-sdk-pr.sh <managed_service_pr_url>
#
# Outputs:
#   If found: sdk_pr_number and sdk_pr_branch to stdout
#   Exit code 0 if found, 1 if not found

MANAGED_SERVICE_PR_URL="$1"

if [[ -z "${MANAGED_SERVICE_PR_URL:-}" ]]; then
  echo "Error: managed_service_pr_url is required" >&2
  exit 1
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "Error: GH_TOKEN environment variable is not set" >&2
  exit 1
fi

if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
  echo "Error: GITHUB_REPOSITORY environment variable is not set" >&2
  exit 1
fi

echo "Searching for SDK PR corresponding to: $MANAGED_SERVICE_PR_URL" >&2

# Get all open SDK PRs
SDK_OPEN_PRS=$(gh pr list --repo "$GITHUB_REPOSITORY" --state open --json number --jq '.[].number')

for sdk_pr_num in $SDK_OPEN_PRS; do
  echo "Checking SDK PR #$sdk_pr_num" >&2

  # Get all commits in this SDK PR
  SDK_COMMITS=$(gh api "repos/$GITHUB_REPOSITORY/pulls/$sdk_pr_num/commits" --jq '.[].sha')

  # Check each commit's message for the trailer
  for sdk_commit_sha in $SDK_COMMITS; do
    SDK_COMMIT_MSG=$(gh api "repos/$GITHUB_REPOSITORY/git/commits/$sdk_commit_sha" --jq '.message')

    if echo "$SDK_COMMIT_MSG" | grep --quiet --fixed-strings "Managed-service-pr-url: $MANAGED_SERVICE_PR_URL"; then
      echo "Found matching SDK PR #$sdk_pr_num (commit $sdk_commit_sha)" >&2

      # Get the SDK PR branch
      SDK_PR_BRANCH=$(gh pr view "$sdk_pr_num" --repo "$GITHUB_REPOSITORY" --json headRefName --jq '.headRefName')

      # Output results
      echo "sdk_pr_number=$sdk_pr_num"
      echo "sdk_pr_branch=$SDK_PR_BRANCH"
      exit 0
    fi
  done
done

echo "No matching SDK PR found" >&2
exit 1
