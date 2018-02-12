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

# Set minimal config. You should overwrite this with better paths.
PIDFILE="${PWD}/${0}.pid"
LOGFILE="${PWD}/${0}.log"

pprint () {
    # Function to properly wrap and print text
    # Usage:
    #   command | pprint
    #       or
    #   pprint <<< "text"
    # Do not set CURRENT_FUNC here, as we want to inherit it
    fold -sw "$(WIDTH="$(tput cols)" ; echo "${WIDTH:-80}")"
}

log () {
    # Function to send log output to stdout and file
    # Usage:
    #     command |& log $SEVERITY
    #         or
    #     log $SEVERITY $MESSAGE
    # Do not set CURRENT_FUNC here, as we want to inherit it
    date +"%x %X | ${0} [${CURRENT_FUNC:-SCRIPT_ROOT}] | ${1:-DEBUG} | ${2:-$(cat /dev/stdin)}" | tee -a "${LOGFILE}" | pprint >&2
}

# Shorthand log functions
log_debug () { log "DEBUG" "$*" ; }
log_info () { log "INFO" "$*" ; }
log_warn () { log "WARN" "$*" ; }
log_err () { log "ERROR" "$*" ; }

quit () {
    # Function to log a message and exit
    # Usage:
    #    quit $SEVERITY $MESSAGE $EXITCODE
    local CURRENT_FUNC="quit"
    log "${1:-WARN}" "${2:-Exiting without reason}"
    exit "${3:-3}"

}

# Trap for killing runaway processes and exiting
trap "quit 'UNKNOWN' 'Exiting on signal' '3'" SIGINT SIGTERM

bash4check () {
    # Call this function to enable features that depend on bash 4.0+.
    # Do not set CURRENT_FUNC here, as we want to inherit it
    if [ ${BASH_VERSINFO[0]} -lt 4 ]
    then
        echo "Sorry, you need at least bash version 4.0 to run this function: $CURRENT_FUNC" >&2
        return 1
    fi
}

# The array needs to be defined before setting up finally, but only if this is bash >=4.0
[ ${BASH_VERSINFO[0]} -ge 4 ] && FINALCMDS=()

finally () {
    # Function to perform final tasks before exit
    local CURRENT_FUNC="finally"
    bash4check
    if [ "${#FINALCMDS[@]}" != 0 ]
    then
        for CMD in "${FINALCMDS[@]}"
        do
            eval "${CMD}"
        done
    else
        log "ERROR" "The array of final tasks was empty. Please ensure you set FINALCMDS."
    fi
}

# Trap to do final tasks before exit
[ ${BASH_VERSINFO[0]} -ge 4 ] && trap finally EXIT

checkpid () {
    # Check for and maintain pidfile
    local CURRENT_FUNC="checkpid"
    bash4check
    if [ -f "${PIDFILE}" ] && [ -d "/proc/$(cat "${PIDFILE}")" ]
    then
        quit "WARN" "This script is already running, exiting"
    else
        echo $$ > "${PIDFILE}"
        FINALCMDS+=("rm -v '${PIDFILE}'")
    fi
}

requireuser () {
    # Checks to see if current user matches $REQUIREUSER and exits if not
    local CURRENT_FUNC="requireuser"
    if [ -z $REQUIREUSER ]
    then
        quit "ERROR" "REQUIREUSER is not set"
    elif [ "$REQUIREUSER" != "$USER" ]
    then
        quit "ERROR" "Only $REQUIREUSER is allowed to run this script"
    fi
}

argparser () {
    # Accept command-line arguments
    # You must pass "$@" as the argument to this function for it to work
    # More info here: http://wiki.bash-hackers.org/howto/getopts_tutorial
    local CURRENT_FUNC="argparser"
    while getopts ":shvx" OPT
    do
        case ${OPT} in
            h) usage ;;
            s) source "${OPTARG}" ;;
            v) set -x ;;
            *) quit "ERROR" "Invalid option: '-${OPTARG}'. For usage, try '${0} -h'." ;;
        esac
    done
}

# If a .conf file exists for this script, source it
if [ -f "${0}.conf" ]
then
    source "${0}.conf"
fi
