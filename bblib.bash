#!/bin/bash

# Scripts should fail on all logic errors, as we don't want to let them run amok
set -e
set -o pipefail
set -o functrace
set -o nounset
set -o errexit

# The FINALCMDS array needs to be defined before setting up finally
FINALCMDS=()
# Array to store command history within the script
LOCAL_HISTORY=()

pprint () {
  # Function to format, line wrap, and print piped text
  # Options:
  #   [0-7]|[COLOR]: Prints the ASCII escape code to set color.
  #   [bold]: Prints the ASCII escape code to set bold.
  #   [underline]: Prints the ASCII escape code to set underline.
  #   More info here: http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x405.html
  # Usage:
  #   command | pprint [options]
  #   pprint [options] <<< "text"
  local COLUMNS="${COLUMNS:-$(tput cols)}"
  while (($#)) ; do
    case "$1" in
      0|black) tput setaf 0 ;;
      1|red) tput setaf 1 ;;
      2|green) tput setaf 2 ;;
      3|yellow) tput setaf 3 ;;
      4|blue) tput setaf 4 ;;
      5|magenta) tput setaf 5 ;;
      6|cyan) tput setaf 6 ;;
      7|white) tput setaf 7 ;;
      8|bold) tput bold ;;
      9|underline) tput smul ;;
      *) quit "CRITICAL" "Option '$1' is not defined." ;;
    esac
    shift
  done
  fold -sw "${COLUMNS:-80}"
  tput sgr0
}

inarray () {
  # Function to see if a string is in an array
  # It works by taking all passed variables and seeing if the last one matches any before it.
  # It will return 0 and print the array index that matches on success,
  # and return 1 with nothing printed on failure.
  # Usage: inarray "${ARRAY[@]}" [searchstring]
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

lc () {
  # Convert stdin/arguments to lowercase
  # Usage:
  #   lc [string]
  #   command | lc
  tr "[:upper:]" "[:lower:]" <<< "${@:-$(cat /dev/stdin)}"
}

uc () {
  # Convert stdin/arguments to uppercase
  # Usage:
  #   uc [string]
  #   command | uc
  tr "[:lower:]" "[:upper:]" <<< "${@:-$(cat /dev/stdin)}"
}

hr () {
  # Print horizontal rule
  # Usage: hr [character]
  local CHARACTER="${1:0:1}"
  local COLUMNS=${COLUMNS:-$(tput cols)}
  printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' "${CHARACTER:--}"
}

log () {
  # Function to send log output to file, syslog, and stderr
  # Usage:
  #   command |& log [severity]
  #   log [severity] [message]
  # Variables:
  #   LOGLEVEL: The cutoff for message severity to log (Default is INFO).
  #   LOGFILE: Path to a log file to write messages to (Default is to skip file logging).
  #   TRACEDEPTH: Sets how many function levels above this one to start a stack trace (Default is 1).
  local TRACEDEPTH=${TRACEDEPTH:-1} # 0 would be this function, which is not useful
  case "${FUNCNAME[$TRACEDEPTH]}" in
    # If the function calling the logger is any of these, we want to find what called them
    bash4check|quit) ((TRACEDEPTH++)) ;;
  esac
  local SEVERITY="$(uc "${1:-NOTICE}")"
  local LOGMSG="${2:-$(cat /dev/stdin)}"
  local LOGLEVELS=(EMERGENCY ALERT CRITICAL ERROR WARN NOTICE INFO DEBUG)
  local LOGCOLORS=("red bold underline" "red bold" "red underline" "red" "magenta" "cyan" "white" "yellow")
  local LOGLEVEL="$(uc "${LOGLEVEL:-INFO}")"
  local LOGTAG="${SCRIPT_NAME:-$(basename "$0")} [${FUNCNAME[$TRACEDEPTH]}]"
  local NUMERIC_LOGLEVEL="$(inarray "${LOGLEVELS[@]}" "${LOGLEVEL}")"
  local NUMERIC_LOGLEVEL="${NUMERIC_LOGLEVEL:-6}"
  local NUMERIC_SEVERITY="$(inarray "${LOGLEVELS[@]}" "${SEVERITY}")"
  local NUMERIC_SEVERITY="${NUMERIC_SEVERITY:-5}"
  local n=$'\n'
  # If EMERGENCY, ALERT, CRITICAL, or DEBUG, append stack trace to LOGMSG
  if [ "$SEVERITY" == "DEBUG" ] || [ ${NUMERIC_SEVERITY} -le 2 ] ; then
    LOGMSG+="${n}[${FUNCNAME[$TRACEDEPTH]}:stacktrace] Previous command: ${LOCAL_HISTORY[@]:$((${#LOCAL_HISTORY[@]}-20)):1}"
    for (( i = $TRACEDEPTH; i < ${#FUNCNAME[@]}; i++ )) ; do
      LOGMSG+="${n}[${FUNCNAME[$i]}:stacktrace] ${BASH_SOURCE[$i]}:${BASH_LINENO[$i-1]}"
    done
  fi
  # Split lines of message and log them
  if [ ${NUMERIC_SEVERITY} -le ${NUMERIC_LOGLEVEL} ] ; then
    while read -r LINE ; do
      logger -s -p user.${NUMERIC_SEVERITY} -t "${LOGTAG} " -- "${LINE}"
    done <<< "${LOGMSG}" |& \
      if [ -n "${LOGFILE}" ] ; then
        tee -a "${LOGFILE}" | pprint ${LOGCOLORS[$NUMERIC_SEVERITY]}
      elif [ ! -t 0 ]; then
        pprint ${LOGCOLORS[$NUMERIC_SEVERITY]} < /dev/stdin
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
  # Usage: quit [severity] [message] [exitcode]
  log "${1:-CRITICAL}" "${2:-Exiting without reason}"
  exit "${3:-3}"
}

bash4check () {
  # Call this function to enable features that depend on bash 4.0+.
  # Usage: bash4check
  if [ ${BASH_VERSINFO[0]} -lt 4 ] ; then
    log "ERROR" "Sorry, you need at least bash version 4 to run this function: ${FUNCNAME[1]}"
    return 1
  else
    log "DEBUG" "This script is safe to enable BASH version 4 features"
  fi
}

finally () {
  # Function to perform final tasks before exit
  # Usage: FINALCMDS+=("command arg")
  until [ "${#FINALCMDS[@]}" == 0 ] ; do
    log "DEBUG" "Executing pre-exit command: ${FINALCMDS[-1]}"
    eval "${FINALCMDS[-1]}"
    unset FINALCMDS[-1]
  done
}

checkpid () {
  # Check for and maintain pidfile
  # Usage: checkpid
  local PIDFILE="${PIDFILE:-${0}.pid}"
  if [ ! -d "/proc/$$" ]; then
    quit "ERROR" "This function requires procfs. Are you on Linux?"
  elif [ -f "${PIDFILE}" ] && [ "$(cat "${PIDFILE}" 2> /dev/null)" != "$$" ] ; then
    quit "WARN" "This script is already running with PID $(cat "${PIDFILE}" 2> /dev/null), exiting"
  else
    echo -n "$$" > "${PIDFILE}"
    FINALCMDS+=("rm '${PIDFILE}'")
    log "DEBUG" "PID $$ has no conflicts and has been written to ${PIDFILE}"
  fi
}

requireuser () {
  # Checks to see if current user matches $REQUIREUSER and exits if not.
  # REQUIREUSER can be set as a variable or passed in as an argument.
  # Usage: requireuser [user]
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
# Print usage information
# Usage: usage
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
  # Usage: argparser "$@"
  local OPT=
  local OPTARG=
  local OPTIND=
  while getopts ":s:hv" OPT ; do
    case ${OPT} in
      h) usage ;;
      s) source "${OPTARG}" ;;
      v) set -x ; export LOGLEVEL=DEBUG ;;
      :) quit "ERROR" "Option '-${OPTARG}' requires an argument. For usage, try '${0} -h'." ;;
      *) quit "ERROR" "Option '-${OPTARG}' is not defined. For usage, try '${0} -h'." ;;
    esac
  done
}

prunner () {
  # Run commands in parallel
  # Options:
  #   -t [threads]
  #   -c [command to pass arguments to]
  # Usage:
  #   prunner "command arg" "command"
  #   prunner -c gzip *.txt
  #   find . -maxdepth 1 | prunner -c 'echo found file:' -t 6
  local PQUEUE=()
  # Process option arguments
  local OPT=
  local OPTARG=
  local OPTIND=
  while getopts ":c:t:" OPT ; do
    case ${OPT} in
      c) local PCMD="${OPTARG}" ;;
      t) local THREADS="${OPTARG}" ;;
      :) quit "ERROR" "Option '-${OPTARG}' requires an argument." ;;
      *) quit "ERROR" "Option '-${OPTARG}' is not defined." ;;
    esac
  done
  # Throw away option arguments so that non-option arguments can be queued
  shift $(($OPTIND-1))
  # Add non-option arguments to queue
  for ARG in "$@" ; do
    PQUEUE+=("$ARG")
  done
  # Add lines from stdin to queue
  if [ ! -t 0 ] ; then
    while read -r LINE ; do
      PQUEUE+=("$LINE")
    done
  fi
  local QCOUNT="${#PQUEUE[@]}"
  local INDEX=0
  log "INFO" "Starting parallel execution of $QCOUNT jobs with ${THREADS:-8} threads using command prefix '$PCMD'."
  until [ ${#PQUEUE[@]} == 0 ] ; do
    if [ "$(jobs -rp | wc -l)" -lt "${THREADS:-8}" ] ; then
      log "DEBUG" "Starting command in parallel ($(($INDEX+1))/$QCOUNT): ${PCMD} ${PQUEUE[$INDEX]}"
      eval "${PCMD} ${PQUEUE[$INDEX]}" |& log "DEBUG" || true &
      unset PQUEUE[$INDEX]
      ((INDEX++)) || true
    fi
  done
  wait
  log "INFO" "Parallel execution finished for $QCOUNT jobs."
}

# Trap for killing runaway processes and exiting
trap "quit 'ALERT' 'Exiting on signal' '3'" SIGINT SIGTERM

# Trap to do final tasks before exit
trap finally EXIT

# Trap to capture history within this script for debugging
trap 'LOCAL_HISTORY+=("$BASH_COMMAND")' DEBUG

# If a .conf file exists for this script, source it
if [ -f "${0}.conf" ] ; then
  source "${0}.conf"
fi
