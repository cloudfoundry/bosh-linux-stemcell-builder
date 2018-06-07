#!/bin/bash

set -euo pipefail

: ${BRANCH:?}
: ${TOKEN:?}
: ${PROJECT_ID:?}

FILTER_UNSTARTED=$(jq -rn '"-type:release state:unstarted" | @uri')

UNSTARTED_STORIES=$(curl -s -X GET -H "X-TrackerToken: $TOKEN" "https://www.pivotaltracker.com/services/v5/projects/$PROJECT_ID/stories?filter=$FILTER_UNSTARTED")
FIRST_UNSTARTED_STORY=$(echo "$UNSTARTED_STORIES" | jq '.[0].id')

curl -s -X POST "https://www.pivotaltracker.com/services/v5/projects/$PROJECT_ID/stories" \
  -H "X-TrackerToken: $TOKEN" \
  -H "Content-Type: application/json" \
  -d @- << EOF | jq -r '.url'
{
  "current_state" : "unstarted",
  "estimate" : 1,
  "name" : "_$(date +%Y-%0m-%0d)_ - stemcell periodic bump [**$BRANCH**]",
  "description" : "It's time to build a new version of stemcells which include the latest upstream vulnerability fixes. The pipeline should have automatically triggered when this story was created to kick off that process.\\n\\nEnsure the OS image and subsequent stemcell builds finished successfully.\\n\\n**Acceptance Criteria**\\n\\n* A new version of the stemcell can be published from the pipeline.",
  "story_type" : "feature",
  "labels" : ["$BRANCH", "stemcell", "sec"],
  "before_id" : $FIRST_UNSTARTED_STORY
}
EOF
