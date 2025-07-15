#!/bin/bash

set -xe

if [ -z "$APP" ]; then
    echo "ERROR: 'APP' is not set."
    exit 1
elif [ ! -f "/app/$APP" ]; then
    echo "ERROR: App runner /app/app.py not found!"
    exit 1
fi

exec streamlit run "/app/$APP"
