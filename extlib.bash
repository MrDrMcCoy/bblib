#!/bin/bash

HELPTEXT="
Put your description, usage, and help text here
"

# script should fail on all logic errors, as we don't want to let it run amok
set -e
set -o pipefail

PIDFILE="/tmp/$0.pid"
LOG_PATH="/tmp/$0.log"

pprint () {
    # Function to properly wrap and print text
    # Usage:
    #   command | pprint
    #       or
    #   pprint <<< "text"
    fold -sw "$(WIDTH="$(tput cols)" ; echo "${WIDTH:-80}")"
}

log () {
    # Function to send log output to stdout and file
    # Usage:
    #     command |& log $SEVERITY
    #         or
    #     log $SEVERITY $MESSAGE
    date +"%x %X | $0 | ${1:-DEBUG} | ${2:-$(cat /dev/stdin)}" | tee -a "$LOG_PATH" | pprint 1>&2
}

quit () {
    # Function to log a message, remove pid file, and exit
    # Usage:
    #    quit $SEVERITY $MESSAGE $EXITCODE
    log "${1:-WARN}" "${2:-Exiting without reason}"
    exit "${3:-3}"
}

finally () {
    # Function to perform final tasks before exit
    rm "$PIDFILE"
}

# trap to do final tasks before exit
trap finally EXIT
# trap for killing runaway processes and cleaning up pidfile
trap "quit 'UNKNOWN' 'Exiting on signal' '3'" SIGINT SIGTERM

# Check for and maintain pidfile
if [ \( -f PIDFILE \) -a \( -d "/proc/$(cat "$PIDFILE" 2> /dev/null)" \) ]
then
    quit "WARN" "$0 is already running, exiting"
else
    #pidfile DOES NOT EXIST
    echo $$ > "$PIDFILE"
    log "INFO" "Starting $0"
fi

quit 'INFO' 'All tasks completed successfully'
