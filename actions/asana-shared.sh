#!/bin/bash
# Shared Asana helpers. Source from action scripts via:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/../asana-shared.sh"

asana_api_url="https://app.asana.com/api/1.0"
pr_prefix="PR:"

# Fetch the subtasks of an Asana task and project them into a flat shape.
# Args: $1 = task_id
# Requires: ASANA_ACCESS_TOKEN env var
# Outputs (stdout): JSON array of { task_id, task_name, task_completed, assignee, parent_name }
_fetch_subtasks() {
	local asana_task_id="$1"
	local url="${asana_api_url}/tasks/${asana_task_id}/subtasks?opt_fields=name,completed,parent.name,assignee"

	local response
	response="$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}")"

	jq -c '[
		.data[] | {
			task_id: .gid,
			task_name: .name,
			task_completed: .completed,
			assignee: .assignee.gid,
			parent_name: .parent.name
		}
	]' <<< "$response"
}
