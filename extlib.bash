#!/bin/bash

HELPTEXT="
$0: An example script

Description:
Put your description here.

Options:
-h: Print this help
-o [key=value]: Append key and value to CONFIG array within script.
-s [source-file-path]: Source a bash file with extra functions and variables.
-v: Enables debugging output for this script
-x: Print the contents of CONFIG array within this script. Should be specified last to ensure all options are caputred.
"

# Script should fail on all logic errors, as we don't want to let it run amok
set -e
set -o pipefail

# This script requires bash version >=4.0 to work. Exit with an error if this requirement is not met.
if ((BASH_VERSINFO[0] < 4))
then
    echo "Sorry, you need at least bash-4.0 to run this script." >&2
    exit 1
fi

# Create associative array to store config in. http://wiki.bash-hackers.org/syntax/arrays
declare -A CONFIG
# Populate config array with defaults
CONFIG=(
    [PIDFILE]="/tmp/$0.pid"
    [LOG_PATH]="/tmp/$0.log"
)
# Config values can be accessed with "${CONFIG[KEY]}"

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
    date +"%x %X | $0 | ${1:-DEBUG} | ${2:-$(cat /dev/stdin)}" | tee -a "${CONFIG[LOG_PATH]}" | pprint >&2
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
    rm "${CONFIG[PIDFILE]}"
}

# Trap to do final tasks before exit
trap finally EXIT

# Trap for killing runaway processes and exiting
trap "quit 'UNKNOWN' 'Exiting on signal' '3'" SIGINT SIGTERM

configset () {
    # Sets key and value in CONFIG where arguments are a "key=value" string
    for KV in "$@"
    do
        CONFIG[${KV%%=*}]=${KV##*=}
    done
}

configprint () {
    # Prints the contents of the CONFIG array
    echo -e '\nScript config:'
    for key in "${!CONFIG[@]}"
    do
        pprint <<< $'\t'"$key=${CONFIG[$key]}"
    done
    echo
}

# Check for and maintain pidfile
if [ \( -f "${CONFIG[PIDFILE]}" \) -a \( -d "/proc/$(cat "${CONFIG[PIDFILE]}" 2> /dev/null)" \) ]
then
    quit "WARN" "$0 is already running, exiting"
else
    echo $$ > "${CONFIG[PIDFILE]}"
    log "INFO" "Starting $0"
fi

#####
# Parse options
#####
# Accept command-line arguments
# More info here: http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":o:shvx" OPT
do
    case $OPT in
        h) pprint <<< "$HELPTEXT" ;;
        o) configset "$OPTARG" ;;
        s) source "$OPTARG" ;;
        v) set -x ;;
        x) configprint ;;
        *) quit "ERROR" "Invalid option: '-$OPTARG'. For usage, try '$0 -h'." ;;
    esac
done

#####
# Put your things here!
#####
#log 'INFO' 'Starting tasks'

#quit 'INFO' 'All tasks completed successfully'
