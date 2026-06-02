#!/bin/bash
#
# Posts a comment (story) on an Asana task. Inputs are read from environment variables:
# ASANA_ACCESS_TOKEN, TASK_ID, COMMENT.
#

set -e -o pipefail

asana_api_url="https://app.asana.com/api/1.0"

main() {
	local url="${asana_api_url}/tasks/${TASK_ID}/stories"

	local payload
	payload=$(jq -n --arg text "$COMMENT" '{ data: { text: $text } }')

	curl -fLSs -X POST "$url" \
		-H "Authorization: Bearer ${ASANA_ACCESS_TOKEN}" \
		-H 'accept: application/json' \
		-H 'content-type: application/json' \
		--data "${payload}" > /dev/null
}

main
