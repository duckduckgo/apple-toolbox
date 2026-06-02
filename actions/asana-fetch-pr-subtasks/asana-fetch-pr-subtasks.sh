#!/bin/bash
#
# Fetches PR review subtasks of a parent Asana task, optionally filtered by reviewer.
# Reads env: ASANA_ACCESS_TOKEN, PARENT_TASK_ID, REVIEWER_USER, ASSIGNEE_FILTER, REPO_NAME
# Writes:   subtask-ids=<json-array> to $GITHUB_OUTPUT
#

set -e -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../asana-shared.sh"

# Caller asked for a filter, but the reviewer couldn't be mapped to an Asana user.
# Soft-skip: emit empty result so the workflow can branch on it without failing.
if [[ -n "$REVIEWER_USER" && -z "$ASSIGNEE_FILTER" ]]; then
	echo "::warning::Skipping fetch: GitHub user ${REVIEWER_USER} has no Asana mapping"
	echo 'subtask-ids=[]' >> "$GITHUB_OUTPUT"
	exit 0
fi

subtasks=$(_fetch_subtasks "$PARENT_TASK_ID")

# Filter rules:
#   - task_name matches the "PR: ... (REPO_NAME)" naming convention
#   - if ASSIGNEE_FILTER is non-empty, assignee gid must match it (else accept all)
subtask_ids=$(jq -c \
	--arg prefix "$pr_prefix" \
	--arg repo "$REPO_NAME" \
	--arg assignee "$ASSIGNEE_FILTER" \
	'[ .[]
	   | select(.task_name | startswith($prefix) and endswith("(" + $repo + ")"))
	   | select($assignee == "" or .assignee == $assignee)
	   | .task_id
	 ]' <<< "$subtasks")

echo "subtask-ids=${subtask_ids}" >> "$GITHUB_OUTPUT"
