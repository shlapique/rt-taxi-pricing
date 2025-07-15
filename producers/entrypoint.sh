#!/bin/bash

# set -xe

if [ -z "$PRODUCER" ]; then
    echo "ERROR: 'PRODUCER' is not set."
    exit 1
elif [ ! -f "/app/$PRODUCER" ]; then
    echo "ERROR: Producer runner /app/$PRODUCER not found!"
    exit 1
fi

STATE_FILE="/shared-state/state.txt"

if [ ! -f "$STATE_FILE" ]; then
    touch "$STATE_FILE"
fi

# lock
exec 3>"$STATE_FILE.lock"
flock 3

IFS=',' read -ra PAIRS <<< "$TOPIC_DATA"
EXPECTED_NUM=${#PAIRS[@]}

if [ "$TOPICS_NUM" -ne "$EXPECTED_NUM" ]; then
    echo "ERROR: Mismatch: TOPICS_NUM=$TOPICS_NUM, but calculated=$EXPECTED_NUM!"
    echo "Check '.env' config"
    exit 1
fi

SELECTED_PAIR=""
for PAIR in "${PAIRS[@]}"; do
    if ! grep -q "^$PAIR$" "$STATE_FILE"; then
        SELECTED_PAIR="$PAIR"
        echo "$PAIR" >> "$STATE_FILE"
        break
    fi
done

# release
flock -u 3
exec 3>&-

if [ -z "$SELECTED_PAIR" ]; then
    echo "ERROR: No free topic:data pair found!"
    exit 1
fi

TOPIC=${SELECTED_PAIR%%:*}
DATA_FILE=${SELECTED_PAIR#*:}

if [ ! -f "/input-data/$DATA_FILE" ]; then
    echo "ERROR: Data file /input-data/$DATA_FILE not found!"
    exit 1
fi

export TOPIC
export DATA="/input-data/$DATA_FILE"

echo "INFO: Starting producer with DATA=$DATA and TOPIC=$TOPIC..."

exec python "/app/$PRODUCER"
