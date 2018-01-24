#!/bin/bash

usage () {
cat << HERE
$0: An example script

Description:
Put your description here.

Options:
-h: Print this help
-s [source-file-path]: Source a bash file with extra functions and variables.
-v: Enables debugging output for this script
HERE
}

# Script should fail on all logic errors, as we don't want to let it run amok
set -e
set -o pipefail

# Set minimal config
PIDFILE="/tmp/$0.pid"
LOGFILE="/tmp/$0.pid"
# If a .conf file exists for this script, source it immediately
if [ -f "$0.conf" ]
then
    source "$0.conf"
fi

checkbashversion () {
    # Call this function for safety if you use associative arrays or other bash 4.0+ features.
    if (( BASH_VERSINFO[0] < 4 ))
    then
        echo "Sorry, you need at least bash-4.0 to run this script." >&2
        exit 1
    fi
}

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
    date +"%x %X | $0 | ${1:-DEBUG} | ${2:-$(cat /dev/stdin)}" | tee -a "${LOGFILE}" | pprint >&2
}

# Shorthand log functions
log_info () { log "INFO" "$*" ; }
log_warn () { log "WARN" "$*" ; }
log_err () { log "ERROR" "$*" ; }

quit () {
    # Function to log a message and exit
    # Usage:
    #    quit $SEVERITY $MESSAGE $EXITCODE
    log "${1:-WARN}" "${2:-Exiting without reason}"
    exit "${3:-3}"
}

finally () {
    # Function to perform final tasks before exit
    if [ -f "${PIDFILE}" ]
    then
        rm "${PIDFILE}"
    fi
}

# Trap to do final tasks before exit
trap finally EXIT

# Trap for killing runaway processes and exiting
trap "quit 'UNKNOWN' 'Exiting on signal' '3'" SIGINT SIGTERM

argparser () {
    # Accept command-line arguments
    # More info here: http://wiki.bash-hackers.org/howto/getopts_tutorial
    while getopts ":o:shvx" OPT
    do
        case $OPT in
            h) usage ;;
            s) source "$OPTARG" ;;
            v) set -x ;;
            *) quit "ERROR" "Invalid option: '-$OPTARG'. For usage, try '$0 -h'." ;;
        esac
    done
}

checkpid () {
    # Check for and maintain pidfile
    if [ \( -f "${PIDFILE}" \) -a \( -d "/proc/$(cat "${PIDFILE}" 2> /dev/null)" \) ]
    then
        quit "WARN" "$0 is already running, exiting"
    else
        echo $$ > "${PIDFILE}"
        log_info "Starting $0"
    fi
}
