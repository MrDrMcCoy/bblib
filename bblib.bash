#!/bin/bash

# Scripts should fail on all logic errors, as we don't want to let them run amok
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail

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
  local -i COLUMNS="${COLUMNS:-$(tput cols)}"
  local PREFIX=
  while (($#)) ; do
    case "$1" in
      0|black) PREFIX+="$(tput setaf 0)" ;;
      1|red) PREFIX+="$(tput setaf 1)" ;;
      2|green) PREFIX+="$(tput setaf 2)" ;;
      3|yellow) PREFIX+="$(tput setaf 3)" ;;
      4|blue) PREFIX+="$(tput setaf 4)" ;;
      5|magenta) PREFIX+="$(tput setaf 5)" ;;
      6|cyan) PREFIX+="$(tput setaf 6)" ;;
      7|white) PREFIX+="$(tput setaf 7)" ;;
      8|bold) PREFIX+="$(tput bold)" ;;
      9|underline) PREFIX+="$(tput smul)" ;;
      *) quit "CRITICAL" "Option '$1' is not defined." ;;
    esac
    shift
  done
  fold -sw "${COLUMNS:-80}" <<< "${PREFIX}$(cat /dev/stdin)$(tput sgr0)"
}

inarray () {
  # Function to see if a string is in an array
  # It works by taking all passed variables and seeing if the last one matches any before it.
  # It will return 0 and print the array index that matches on success,
  # and return 1 with nothing printed on failure.
  # Usage: inarray "${ARRAY[@]}" [searchstring]
  local -i INDICIES=$#
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
  local -i COLUMNS=${COLUMNS:-$(tput cols)}
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
  local -u SEVERITY="${1:-NOTICE}"
  local LOGMSG="${2:-$(cat /dev/stdin)}"
  [[ -n "$LOGMSG" ]] || return 0
  local -i TRACEDEPTH=${TRACEDEPTH:-1} # 0 would be this function, which is not useful
  until [[ ! "${FUNCNAME[$TRACEDEPTH]}" =~ bash4check|quit|log ]] ; do
    # We want to look above these functions as well
    ((TRACEDEPTH++))
  done
  local LOGTAG="${SCRIPT_NAME:-$(basename "$0")} ${FUNCNAME[$TRACEDEPTH]}"
  local -a LOGLEVELS=(EMERGENCY ALERT CRITICAL ERROR WARN NOTICE INFO DEBUG)
  local -a LOGCOLORS=("red bold underline" "red bold" "red underline" "red" "magenta" "cyan" "white" "yellow")
  local -u LOGLEVEL="${LOGLEVEL:-INFO}"
  local -i NUMERIC_LOGLEVEL="$(inarray "${LOGLEVELS[@]}" "${LOGLEVEL}")"
  local -i NUMERIC_LOGLEVEL="${NUMERIC_LOGLEVEL:-6}"
  local -i NUMERIC_SEVERITY="$(inarray "${LOGLEVELS[@]}" "${SEVERITY}")"
  local -i NUMERIC_SEVERITY="${NUMERIC_SEVERITY:-5}"
  # If EMERGENCY, ALERT, CRITICAL, or DEBUG, append stack trace to LOGMSG
  if [[ "$SEVERITY" == "DEBUG" ]] || [[ "${NUMERIC_SEVERITY}" -le 2 ]] ; then
    # If DEBUG, include the command that was run
    [[ "$SEVERITY" != "DEBUG" ]] || LOGMSG+=" $(eval echo "Command: ${PWD} \$ ${LOCAL_HISTORY[-$((TRACEDEPTH+19))]}" 2>/dev/null || true)"
    for (( i = TRACEDEPTH; i < ${#FUNCNAME[@]}; i++ )) ; do
      LOGMSG+=" > ${BASH_SOURCE[$i]}:${FUNCNAME[$i]}:${BASH_LINENO[$i-1]}"
    done
  fi
  # Send message to logger
  if [ "${NUMERIC_SEVERITY}" -le "${NUMERIC_LOGLEVEL}" ] ; then
    tr '\n' ' ' <<< "${LOGMSG}" | logger -s -p "user.${NUMERIC_SEVERITY}" -t "${LOGTAG} " |& \
      if [ -n "${LOGFILE:-}" ] ; then
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
  if [ "${BASH_VERSINFO[0]}" -lt 4 ] ; then
    quit "ALERT" "Sorry, you need at least bash version 4 to run this function: ${FUNCNAME[1]}"
  else
    log "DEBUG" "This script is safe to enable BASH version 4 features"
  fi
}

finally () {
  # Function to perform final tasks before exit
  # Usage: FINALCMDS+=("command arg")
  until [[ "${#FINALCMDS[@]}" == 0 ]] ; do
    ${FINALCMDS[-1]} |& log "DEBUG"
    unset "FINALCMDS[-1]"
  done
}

checkpid () {
  # Check for and maintain pidfile
  # Usage: checkpid
  local PIDFILE="${PIDFILE:-${0}.pid}"
  if [[ ! -d "/proc/$$" ]]; then
    quit "ERROR" "This function requires procfs. Are you on Linux?"
  elif [[ ! -f "${PIDFILE}" ]] ; then
    echo -n "$$" > "${PIDFILE}"
    FINALCMDS+=("rm -v '${PIDFILE}'")
    log "DEBUG" "PID $$ has no conflicts and has been written to ${PIDFILE}"
  elif [[ "$( cat "${PIDFILE}" || true )" -ne $$ ]] ; then
    quit "ERROR" "This script is already running, exiting."
  else
    quit "ALERT" "Unknown error verifying unique PID."
  fi
}

requireuser () {
  # Checks to see if current user matches $REQUIREUSER and exits if not.
  # REQUIREUSER can be set as a variable or passed in as an argument.
  # Usage: requireuser [user]
  local REQUIREUSER="${1:-${REQUIREUSER:-}}"
  if [ -z "${REQUIREUSER:-}" ] ; then
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
  [ -n "$*" ] || quit "ERROR" "No arguments were passed."
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
  local -a PQUEUE=()
  local PCMD=
  # Process option arguments
  while (($#)) ; do
    case "$1" in
      --command|-c) shift ; local PCMD="$1" ;;
      --threads|-t) shift ; local -i THREADS="$1" ;;
      -*) quit "ERROR" "Option '$1' is not defined." ;;
      *) PQUEUE+=("$1") ;;
    esac
    shift
  done
  # Add lines from stdin to queue
  if [ ! -t 0 ] ; then
    while read -r LINE ; do
      PQUEUE+=("$LINE")
    done
  fi
  local -i QCOUNT="${#PQUEUE[@]}"
  local -i INDEX=0
  until [ ${#PQUEUE[@]} == 0 ] ; do
    if [ "$(jobs -rp | wc -l)" -lt "${THREADS:-8}" ] ; then
      ${PCMD} ${PQUEUE[$INDEX]} 2> >(log "ERROR") | log "DEBUG" &
      unset "PQUEUE[$INDEX]"
      ((INDEX++)) || true
    fi
  done
  wait
}

# Trap to do final tasks before exit
trap finally EXIT

# Trap for killing runaway processes and exiting
trap "quit 'ALERT' 'Exiting on signal' '3'" SIGINT SIGTERM

# Trap to capture errors
trap 'quit "ALERT" "Command failed with exit code $?: $BASH_COMMAND" "$?"' ERR

# Trap to capture history within this script for debugging
trap 'LOCAL_HISTORY+=("$BASH_COMMAND")' DEBUG

# If a .conf file exists for this script, source it
if [ -f "${0}.conf" ] ; then
  source "${0}.conf"
fi
