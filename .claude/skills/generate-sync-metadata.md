# Generate Sync Metadata

This skill is ONLY for the automated OpenAPI sync workflow (scripts/openapi-sync-update-changelog.sh).
Do not use this skill for manual changelog updates or other changelog work.

Analyze the OpenAPI spec sync changes, update CHANGELOG.md, and generate structured metadata (commit title, commit body, PR title, PR description) for the sync.

## CRITICAL: Source of Truth

**The diff file at `/tmp/openapi-sync-diff.txt` is your ONLY source of truth.**
- `/tmp/openapi-sync-diff-stat.txt` is a file-by-file summary of that same diff, provided only as a navigation aid - do not document anything based on the summary alone
- Document ONLY what appears in the diff - nothing more, nothing less
- If something is not in the diff, do NOT document it
- All changelog entries, commit messages, and PR descriptions must be based ONLY on what you see in the diff

## Instructions

**Step 1: View the changes**
- Read `/tmp/openapi-sync-diff-stat.txt` for an overview of which files changed
- Read `/tmp/openapi-sync-diff.txt` for the full diff. You'll need to read the entire diff to ensure you don't miss any changes. It may be large - use the Read tool's offset and limit parameters to page through it until you have seen all of it, reading as much as you can in each turn to save round trips. Do not stop after the first page.

**Step 2: Update CHANGELOG.md**
- Follow the changelog conventions documented in CLAUDE.md
- IMPORTANT: Only modify CHANGELOG.md. Do not modify any other files including generated code, spec files, or configuration files

**Step 3: Generate commit and PR metadata**
- Follow the guidelines in the "Output Format" section below

## Output Format

End your response with these exact markers and formatting:

```
---COMMIT_TITLE---
<one line, max 72 characters>
---COMMIT_BODY---
<multi-line, wrap at 72 characters>
---PR_TITLE---
<one line, max 72 characters>
---PR_DESCRIPTION---
<multi-line, no wrap limit>
```

Do not add any text after the PR description section.

## Writing Guidelines

**For Commit Body:**
- Describe the actual SDK/API changes from a user perspective
- Focus on WHAT changed in the API/SDK, not the process of updating files
- DO NOT include file lists - focus on user-facing API/SDK changes
- Provide a high-level summary (e.g., what new operations are available, what fields were added/modified)
- Group related changes together (e.g., "Added JWT issuer management operations including create, get, list, update, and delete")
- For breaking changes, clearly call out what changed and why it might break existing code

**For PR Description:**
- Start with a reader-friendly summary (2-3 sentences)
- Describe the actual SDK/API changes from a user perspective, similar to the commit body
- DO NOT include file lists - focus on user-facing API/SDK changes
- Can be more detailed than commit body - include context that helps reviewers understand the changes

**For Commit Titles and PR Titles:**
- Use imperative mood (e.g., "Add", "Update", "Fix", not "Added", "Updated", "Fixed")
- DO NOT write titles like "Update CHANGELOG.md" - the changelog update is just a side effect, not the main change
- Titles must be under 72 characters (strict limit)
- If changes are focused on one specific area, describe that clearly (e.g., "Add MFA audit log actions", "Update invoice field descriptions")
- For multiple unrelated changes: review your title against all affected endpoints and fields. If your title doesn't cover everything or exceeds 72 characters, use the generic title "Sync OpenAPI spec from managed-service" and describe the changes in the commit body instead.
