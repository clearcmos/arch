#!/bin/bash
# Timer CLI wrapper - activates venv and runs timer.py
exec /home/nicholas/git/timer-cli/.venv/bin/python /home/nicholas/git/timer-cli/cli/timer.py "$@"
