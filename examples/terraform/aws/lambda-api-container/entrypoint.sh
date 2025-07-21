#!/bin/bash

if [ "$RUN_MODE" == "ECS" ]; then
    # ECS mode - run Flask web server
    cd /var/task
    python lambda_function.py
else
    # Lambda mode - run lambda runtime
    exec "$@"
fi