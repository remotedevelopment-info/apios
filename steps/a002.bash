#!/usr/bin/env bash

export DOCKER_CLI_HINTS=false

set -e

echo "Step 1: Run ACTION-002 (Initialize AI Agent workspace)"

# Example: create a workspace dir for agents
docker exec -it apios bash -c "mkdir -p /workspace/agents"

echo "Step 2: Verify workspace directory"
docker exec -it apios bash -c "ls -l /workspace"

echo "Step 3: Register AI Agent in MongoDB"
docker exec -it apios bash -c "\
python3 - <<'PYTHON'
from pymongo import MongoClient
client = MongoClient('mongodb://apios-mongo:27017/')
db = client.apios_db
agents = db.agents
if agents.count_documents({ 'name': 'Agent001' }) == 0:
    agents.insert_one({
        'name': 'Agent001',
        'role': 'software_builder',
        'status': 'initialized'
    })
print('Agents:', list(agents.find({}, {'_id':0})))
PYTHON
"

echo "Step 4: Confirm agent record"
docker exec -it apios bash -c "\
sqlite3 /data/apios_local.sqlite \"SELECT name FROM sqlite_master WHERE type='table';\"
"

echo "ACTION-002 completed successfully!"

