#!/bin/bash
#
# This script creates a PR subtask and assign it to a team member when a review is requested on GitHub
# 

set -e -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../asana-shared.sh"

# Sets the parent task name
_set_parent_task_name() {
	local subtasks="$1"
	local asana_task_id="$2"

	# extracts the parent name from the first object  
	parent_task_name=$(echo "$subtasks" | jq -r '.[0].parent_name')

	# if parent_task_name is nil it means that there are no subtask in the current task so we fetch the parent name
	if [ -z "$parent_task_name" ] || [ "$parent_task_name" = "null" ]; then
		local url="${asana_api_url}/tasks/${asana_task_id}"
		parent_task_name="$(curl -fLSs "$url" -H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" | jq -r '.data.name')"
	fi
}

# Checks if a subtask for the PR already exists.
_check_pr_subtask_exist() {
	local response="$1"
	local asana_assignee_id="$2"
	local github_repo_name="$3"

	# read each line of the array
	# extract the task name and trim leading and trailing white spaces
	# extract the assignee name
	# checks if the task name has 'PR:' prefix the repository name as suffix and if it's assigned to the reviewer
	echo "$response" | jq -c '.[]' | while read -r item; do
		task_name=$(jq -r '.task_name' <<< "$item" | awk '{$1=$1};1')
		assignee=$(jq -r '.assignee' <<< "$item")

		if [[ "$task_name" == "${pr_prefix}"*"(${github_repo_name})" && "$assignee" == "$asana_assignee_id" ]]; then
    		echo "$item"
		fi
	done

}

# Gets the next business day (skips weekends)
_get_next_business_day() {
    local next_date
    next_date=$(date -d "+1 day" "+%Y-%m-%d")
    
    # Check if the next day is a weekend
    local day_of_week
    day_of_week=$(date -d "$next_date" "+%u")
    
    if [ "$day_of_week" = "6" ]; then  # Saturday
        next_date=$(date -d "$next_date +2 days" "+%Y-%m-%d")
    elif [ "$day_of_week" = "7" ]; then  # Sunday
        next_date=$(date -d "$next_date +1 day" "+%Y-%m-%d")
    fi
    
    echo "${next_date}"
}

# Creates a subtask called PR: ${task_title}, set the PR URL as description and assign to the requested reviewer
_create_pr_subtask() {
	local asana_task_id="$1"
	local asana_assignee_id="$2"
	local github_pr_url="$3"
	local github_repo_name="$4"
	local asana_author_id="$5"
	local asana_project_id="$6"
	local asana_section_id="$7"

	local url="${asana_api_url}/tasks/${asana_task_id}/subtasks?opt_fields=gid"
	local task_name="${pr_prefix} ${parent_task_name} (${github_repo_name})"
	local due_date=$(_get_next_business_day)

	# Always include the reviewer (assignee). Setting `assignee` via the API
	# does NOT auto-add them to `followers`, so without this they would miss
	# inbox notifications for activity on the subtask (e.g. automated comments).
	# Add the author only when distinct from the reviewer.
	local followers_json
	if [[ -n "$asana_author_id" && "$asana_author_id" != "$asana_assignee_id" ]]; then
		followers_json=$(jq -nc \
			--arg reviewer "$asana_assignee_id" \
			--arg author "$asana_author_id" \
			'[$reviewer, $author]')
	else
		followers_json=$(jq -nc --arg reviewer "$asana_assignee_id" '[$reviewer]')
	fi

	local payload
	payload=$(jq -n \
		--arg assignee "$asana_assignee_id" \
		--arg notes "${pr_prefix} ${github_pr_url}" \
		--arg name "$task_name" \
		--arg due_on "$due_date" \
		--argjson followers "$followers_json" \
		'{ data: { assignee: $assignee, notes: $notes, name: $name, due_on: $due_on, followers: $followers } }'
	)

	local created_gid
	created_gid=$(_execute_create_or_update_asana_task_request POST "$url" "$payload")

	# Optionally file the new subtask into a tracking project (and section).
	# Gated on a non-empty project id so other consumers of this action, which
	# don't pass these inputs, are unaffected.
	if [[ -n "$asana_project_id" ]]; then
		_add_task_to_project "$created_gid" "$asana_project_id" "$asana_section_id"
	fi
}

# Assigns a reviewer to the existing PR subtask and update the task status if it is marked 'completed'
_mark_task_uncompleted_if_needed() {
	local pr_subtask="$1"
	
	# get the task id
	local task_id
	task_id=$(echo "$pr_subtask" | jq -r '.task_id')
	# get the completed status
	local task_status_completed
	task_status_completed=$(echo "$pr_subtask" | jq -r '.task_completed')
	
	# if the status is completed mark the task uncompleted.
	if [ "$task_status_completed" = true ]; then
		local url="${asana_api_url}/tasks/${task_id}?opt_fields=gid"
		local payload='{"data":{"completed":false}}'
		_execute_create_or_update_asana_task_request PUT "$url" "$payload"
	fi
}

# Executes an Asana request to create or update a Subtask
_execute_create_or_update_asana_task_request() {
	local method="$1"
	local url="$2"
	local payload="$3"

	local task_id
	task_id="$(curl -fLSs -X "$method" "$url" \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		-H 'accept: application/json' \
		-H 'content-type: application/json' \
		--data "${payload}" \
		| jq -r .data.gid)"

	# Emit the gid so callers can capture it (e.g. to add the new task to a project).
	echo "$task_id"
}

# Adds an existing task to a project, optionally dropping it into a specific
# section. Best-effort: a failure here must not fail the action, since the
# subtask itself was already created successfully.
_add_task_to_project() {
	local task_id="$1"
	local project_id="$2"
	local section_id="$3"

	local url="${asana_api_url}/tasks/${task_id}/addProject"
	local payload
	if [[ -n "$section_id" ]]; then
		payload=$(jq -n --arg project "$project_id" --arg section "$section_id" \
			'{ data: { project: $project, section: $section } }')
	else
		payload=$(jq -n --arg project "$project_id" \
			'{ data: { project: $project } }')
	fi

	if ! curl -fLSs -X POST "$url" \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		-H 'accept: application/json' \
		-H 'content-type: application/json' \
		--data "${payload}" > /dev/null; then
		echo "::warning::Could not add subtask ${task_id} to project ${project_id} (section ${section_id:-none}). The subtask was created regardless."
	fi
}

main() {
	local asana_task_id="$1"
	local asana_assignee_id="$2"
	local github_pr_url="$3"
	local github_repo_name="$4"
	local asana_author_id="$5"
	local asana_project_id="$6"
	local asana_section_id="$7"

	# fetch the task subtasks
	local subtasks
	subtasks=$(_fetch_subtasks "$asana_task_id")

	# set the parent task name
	_set_parent_task_name "$subtasks" "$asana_task_id"

	# check if the PR subtask already exist
	local pr_subtask
	pr_subtask=$(_check_pr_subtask_exist "$subtasks" "$asana_assignee_id" "$github_repo_name")

	# if the PR subtask exist, mark the task uncompleted if it the task is marked completed
	# otherwise, create the PR subtask and assign it to the reviewer
	if [[ -n "$pr_subtask" ]]; then
		_mark_task_uncompleted_if_needed "$pr_subtask"
	else
		_create_pr_subtask "$asana_task_id" "$asana_assignee_id" "$github_pr_url" "$github_repo_name" "$asana_author_id" "$asana_project_id" "$asana_section_id"
	fi
}

main "$@"
