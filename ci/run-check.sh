#!/usr/bin/env bash
# Boots nothing. Assumes n8n is up on localhost:5678.
# Creates an owner, imports a workflow with a Python (native) Code node, runs it,
# prints the execution status and whatever error the Code node produced.
set -u
BASE=http://localhost:5678
J=/tmp/cookies.txt

echo "--- waiting for n8n"
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/rest/settings" || true)
  [ "$code" = "200" ] && break
  sleep 5
done
echo "settings http=$code"

echo "--- owner setup"
curl -s -c "$J" -X POST "$BASE/rest/owner/setup" \
  -H 'content-type: application/json' \
  -d '{"email":"check@example.com","firstName":"Check","lastName":"Run","password":"Password123"}' \
  -o /tmp/setup.json -w 'http=%{http_code}\n'

WF=$(cat ci/py-test.json)

echo "--- create workflow"
curl -s -b "$J" -X POST "$BASE/rest/workflows" -H 'content-type: application/json' \
  -d "$WF" -o /tmp/wf.json -w 'http=%{http_code}\n'
ID=$(jq -r '.data.id // .id // empty' /tmp/wf.json)
echo "workflow id=$ID"
[ -z "$ID" ] && { head -c 500 /tmp/wf.json; exit 1; }

echo "--- run workflow"
jq -n --argjson wf "$WF" --arg id "$ID" '{workflowData: ($wf + {id: $id}), destinationNode: "Code", runData: {}}' > /tmp/run.json
curl -s -b "$J" -X POST "$BASE/rest/workflows/$ID/run" -H 'content-type: application/json' \
  --data-binary @/tmp/run.json -o /tmp/exec.json -w 'http=%{http_code}\n'
EX=$(jq -r '.data.executionId // empty' /tmp/exec.json)
echo "execution id=$EX"
[ -z "$EX" ] && { head -c 800 /tmp/exec.json; exit 1; }

echo "--- result"
for i in $(seq 1 30); do
  curl -s -b "$J" "$BASE/rest/executions/$EX" -o /tmp/res.json
  fin=$(jq -r '.data.finished // false' /tmp/res.json)
  st=$(jq -r '.data.status // "?"' /tmp/res.json)
  [ "$st" != "running" ] && [ "$st" != "new" ] && break
  sleep 3
done
echo "status=$st finished=$fin"
echo "code node output:"
jq -r '.data.data.resultData.runData.Code // "no run data for Code node"' /tmp/res.json | head -c 1200
echo
echo "error:"
jq -r '.data.data.resultData.error.message // "none"' /tmp/res.json
