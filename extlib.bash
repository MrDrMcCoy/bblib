#!/bin/bash

# Scripts should fail on all logic errors, as we don't want to let them run amok
set -e
set -o pipefail

# Configs that need to be exported. You should set these in your source file as appropriate.
# export PIDFILE="${0}.pid"
# export LOGLEVEL="INFO"
# export SCRIPT_NAME="${0}"

# The FINALCMDS array needs to be defined before setting up finally
FINALCMDS=()

pprint () {
  # Function to properly wrap and print text
  # Usage:
  #   command | pprint
  #       or
  #   pprint <<< "text"
  # Do not set CURRENT_FUNC here, as we want to inherit it
  local COLUMNS=${COLUMNS:-$(tput cols)}
  fold -sw "${COLUMNS:-80}"
}

inarray () {
  # Function to see if a string is in an array
  # It works by taking all passed variables and seing if the last one matches any before it.
  # It will return 0 and print the array index that matches on success,
  # and return 1 with nothing printed on failure.
  # Usage:
  #   inarray "${ARRAY[@]}" "SEARCHSTRING"
  #####
  local INDICIES=$#
  local SEARCH=${!INDICIES}
  for ((INDEX=1 ; INDEX < $# ; INDEX++)) {
    if [ "${!INDEX}" == "${SEARCH}" ]; then
      echo "$((INDEX - 1))"
      return 0
    fi
  }
  return 1
}

log () {
  # Function to send log output to STDERR and file
  # Usage:
  #     command |& log $SEVERITY
  #         or
  #     log $SEVERITY $MESSAGE
  # Variables:
  #     LOGLEVEL: The cutoff for message severity to log (Default is INFO).
  # Do not set CURRENT_FUNC here, as we want to inherit it
  #####
  # INPUTS
  local SEVERITY="$(tr "[:lower:]" "[:upper:]" <<< "${1:-DEBUG}")"
  local LOGMSG="${2:-$(cat /dev/stdin)}"
  #####
  # CONFIG
  local LOGLEVELS=(EMERGENCY ALERT CRITICAL ERROR WARN NOTICE INFO DEBUG)
  local LOGLEVEL="$(tr "[:lower:]" "[:upper:]" <<< "${LOGLEVEL:-INFO}")"
  local NUMERIC_LOGLEVEL="$(inarray "${LOGLEVELS[@]}" "${LOGLEVEL}")"
  local NUMERIC_SEVERITY="$(inarray "${LOGLEVELS[@]}" "${SEVERITY}")"
  local LOGTAG="${SCRIPT_NAME:-$0} [${CURRENT_FUNC:-SCRIPT_ROOT}] "
  #####
  if [ $NUMERIC_SEVERITY -le $NUMERIC_LOGLEVEL ] ; then
    while read -r LINE ; do
      logger -is -p user.${NUMERIC_LOGLEVEL} -t "${LOGTAG}" -- "${LINE}"
    done <<< "${LOGMSG}"
  fi
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
  # Do not set CURRENT_FUNC here, as we want to inherit it
  log "${1:-WARN}" "${2:-Exiting without reason}"
  exit "${3:-3}"
}

bash4check () {
  # Call this function to enable features that depend on bash 4.0+.
  # Do not set CURRENT_FUNC here, as we want to inherit it
  if [ ${BASH_VERSINFO[0]} -lt 4 ] ; then
    log "ERROR" "Sorry, you need at least bash version 4 to run this function: $CURRENT_FUNC"
    return 1
  else
    log "DEBUG" "This script is safe to enable BASH version 4 features"
  fi
}

finally () {
  # Function to perform final tasks before exit
  local CURRENT_FUNC="finally"
  if [ "${#FINALCMDS[@]}" != 0 ] ; then
    for CMD in "${FINALCMDS[@]}" ; do
      eval "${CMD}"
    done
  fi
}

checkpid () {
  # Check for and maintain pidfile
  local CURRENT_FUNC="checkpid"
  local PIDFILE="${PIDFILE:-${0}.pid}"
  if [ ! -d "/proc" ]; then
    quit "ERROR" "This function requires procfs. Are you on Linux?"
  elif [ -f "${PIDFILE}" ] && [ -d "/proc/$(cat "${PIDFILE}")" ] ; then
    quit "WARN" "This script is already running, exiting"
  else
    echo $$ > "${PIDFILE}"
    FINALCMDS+=("rm -v '${PIDFILE}'")
    log "DEBUG" "PID $$ has no conflicts and has been written to ${PIDFILE}"
  fi
}

requireuser () {
  # Checks to see if current user matches $REQUIREUSER and exits if not.
  # REQUIREUSER can be set as a variable or passed in as an argument.
  local CURRENT_FUNC="requireuser"
  local REQUIREUSER="${REQUIREUSER:-$*}"
  if [ -z $REQUIREUSER ] ; then
    quit "ERROR" "requireuser was called, but \$REQUIREUSER is not set"
  elif [ "$REQUIREUSER" != "$USER" ] ; then
    quit "ERROR" "Only $REQUIREUSER is allowed to run this script"
  else
    log "DEBUG" "User '$USER' matches '$REQUIREUSER' and is allowed to run this script"
  fi
}

usage () {
pprint << HERE
$0: An example script

Description:
Put your description here.

Options:
-h: Print this help
-s [path]: Source a bash file with extra functions and variables.
-v: Enables debugging output for this script
HERE
}

argparser () {
  # Accept command-line arguments
  # Usage:
  #   argparser "$@"
  # More info here: http://wiki.bash-hackers.org/howto/getopts_tutorial
  local CURRENT_FUNC="argparser"
  while getopts ":shvx" OPT ; do
    case ${OPT} in
      h) usage ;;
      s) source "${OPTARG}" ;;
      v) set -x ; export LOGLEVEL=DEBUG ;;
      *) quit "ERROR" "Invalid option: '-${OPTARG}'. For usage, try '${0} -h'." ;;
    esac
  done
}

# Trap for killing runaway processes and exiting
trap "quit 'UNKNOWN' 'Exiting on signal' '3'" SIGINT SIGTERM

# Trap to do final tasks before exit
trap finally EXIT

# If a .conf file exists for this script, source it
if [ -f "${0}.conf" ] ; then
  source "${0}.conf"
fi
