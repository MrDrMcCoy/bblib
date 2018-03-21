#!/bin/bash

# Scripts should fail on all logic errors, as we don't want to let them run amok
set -e
set -o pipefail

# The FINALCMDS array needs to be defined before setting up finally
FINALCMDS=()

pprint () {
  # Function to properly wrap and print text
  # Usage:
  #   command | pprint
  #   pprint <<< "text"
  local COLUMNS="${COLUMNS:-$(tput cols)}"
  fold -sw "${COLUMNS:-80}"
}

inarray () {
  # Function to see if a string is in an array
  # It works by taking all passed variables and seeing if the last one matches any before it.
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

# Convert to uppercase
uc () { tr "[:lower:]" "[:upper:]" <<< "${@:-$(cat /dev/stdin)}" ; }
# Convert to lowercase
lc () { tr "[:lower:]" "[:upper:]" <<< "${@:-$(cat /dev/stdin)}" ; }
# Print horizontal rule
hr () {
  local CHARACTER="${1:0:1}"
  local COLUMNS=${COLUMNS:-$(tput cols)}
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' "${CHARACTER:--}"
}

log () {
  # Function to send log output to file, syslog, and stderr
  # Usage:
  #     command |& log $SEVERITY
  #     log $SEVERITY $MESSAGE
  # Variables:
  #     LOGLEVEL: The cutoff for message severity to log (Default is INFO).
  #####
  local SEVERITY="$(uc "${1:-NOTICE}")"
  local LOGMSG="${2:-$(cat /dev/stdin)}"
  local LOGLEVELS=(EMERGENCY ALERT CRITICAL ERROR WARN NOTICE INFO DEBUG)
  local LOGLEVEL="$(uc "${LOGLEVEL:-INFO}")"
  local LOGTAG="[${SCRIPT_NAME:-$0}] [${CURRENT_FUNC:-SCRIPT_ROOT}] [${SEVERITY}]"
  local NUMERIC_LOGLEVEL="$(inarray "${LOGLEVELS[@]}" "${LOGLEVEL}")"
  local NUMERIC_SEVERITY="$(inarray "${LOGLEVELS[@]}" "${SEVERITY}")"
  #####
  if [ ${NUMERIC_SEVERITY:-5} -le ${NUMERIC_LOGLEVEL:-6} ] ; then
    while read -r LINE ; do
      logger -is -p user.${NUMERIC_SEVERITY:-5} -t "${LOGTAG} " -- "${LINE}"
    done <<< "${LOGMSG}" |& \
    if [ -n "${LOGFILE}" ] ; then
      tee -a "${LOGFILE}"
    else
      cat /dev/stdin
    fi
  fi 1>&2
}

# Shorthand log functions
log_debug () { log "DEBUG" "$*" ; }
log_info () { log "INFO" "$*" ; }
log_note () { log "NOTICE" "$*" ; }
log_warn () { log "WARN" "$*" ; }
log_err () { log "ERROR" "$*" ; }
log_crit () { log "CRITICAL" "$*" ; }
log_alert () { log "ALERT" "$*" ; }
log_emer () { log "EMERGENCY" "$*" ; }

quit () {
  # Function to log a message and exit
  # Usage:
  #    quit $SEVERITY $MESSAGE $EXITCODE
  log "${1:-WARN}" "${2:-Exiting without reason}"
  exit "${3:-3}"
}

bash4check () {
  # Call this function to enable features that depend on bash 4.0+.
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
      log "DEBUG" "Executing pre-exit command: ${CMD}"
      eval "${CMD}"
    done
  fi
}

checkpid () {
  # Check for and maintain pidfile
  local CURRENT_FUNC="checkpid"
  local PIDFILE="${PIDFILE:-${0}.pid}"
  if [ ! -d "/proc/$$" ]; then
    quit "ERROR" "This function requires procfs. Are you on Linux?"
  elif [ "$(cat "${PIDFILE}" 2> /dev/null)" = "$$" ] ; then
    quit "WARN" "This script is already running with PID $(cat "${PIDFILE}" 2> /dev/null), exiting"
  else
    echo -n "$$" > "${PIDFILE}"
    FINALCMDS+=("rm -v '${PIDFILE}'")
    log "DEBUG" "PID $$ has no conflicts and has been written to ${PIDFILE}"
  fi
}

requireuser () {
  # Checks to see if current user matches $REQUIREUSER and exits if not.
  # REQUIREUSER can be set as a variable or passed in as an argument.
  local CURRENT_FUNC="requireuser"
  local REQUIREUSER="${1:-$REQUIREUSER}"
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
  while getopts ":s:hv" OPT ; do
    case ${OPT} in
      h) usage ;;
      s) source "${OPTARG}" ;;
      v) set -x ; LOGLEVEL=DEBUG ;;
      :) quit "ERROR" "Option '-${OPTARG}' requires an argument. For usage, try '${0} -h'." ;;
      *) quit "ERROR" "Invalid option: '-${OPTARG}'. For usage, try '${0} -h'." ;;
    esac
  done
}

prunner () {
  # Executes jobs in parallel
  # Usage:
  #   prunner "command args" "command args"
  #   command_generator | prunner
  #   prunner -t 6 -c gzip FILE FILE FILE
  #   find . -type f | prunner -c gzip -t 8
  local CURRENT_FUNC="prunner"
  local JOB_QUEUE=()
  local COMMAND=""
  # Process options
  while getopts ":c:t:" OPT ; do
    case ${OPT} in
      c) local COMMAND="${OPTARG}" ;;
      t) local THREADS="${OPTARG}" ;;
      :) quit "ERROR" "Option '-${OPT}' requires an argument." ;;
      *) JOB_QUEUE+=("${OPTARG}") ;;
    esac
  done
  # Add input lines to queue, split by newlines
  if [ ! -t 0 ] ; then
    while read -r LINE ; do
      JOB_QUEUE+=("$LINE")
    done <<< "$(cat /dev/stdin)"
  fi
  local JOB_MAX="${#JOB_QUEUE[@]}"
  local JOB_INDEX=0
  local THREADS=${THREADS:-8}
  # Start running the commands in the queue
  log "DEBUG" "Starting parallel execution of $JOB_MAX jobs with $THREADS threads."
  until [ ${#JOB_QUEUE[@]} = 0 ] ; do
    if [ "$(jobs -rp | wc -l)" -lt "${THREADS}" ] ; then
      log "DEBUG" "Starting command in parallel ($(($JOB_INDEX+1))/$JOB_MAX): ${COMMAND} ${JOB_QUEUE[$JOB_INDEX]}"
      eval "${COMMAND} ${JOB_QUEUE[$JOB_INDEX]}" |& log "DEBUG" &
      unset JOB_QUEUE[$JOB_INDEX]
      ((JOB_INDEX++))
    fi
  done
  log "DEBUG" "Parallel execution finished for $JOB_MAX jobs."
}

# Trap for killing runaway processes and exiting
trap "quit 'ALERT' 'Exiting on signal' '3'" SIGINT SIGTERM

# Trap to do final tasks before exit
trap finally EXIT

# If a .conf file exists for this script, source it
if [ -f "${0}.conf" ] ; then
  source "${0}.conf"
fi
