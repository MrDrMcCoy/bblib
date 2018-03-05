#!/bin/bash

#####
# This script shows an example of advanced looping, avoiding subshells, and employing GNU Parallel.
#####

# Load the base function library
source extlib.bash
source concurrencylib.bash

# You can set the name of this script to be anything you like
export SCRIPT_NAME="Advanced Example"

# The advanced example uses BASH 4 functions
bash4check

logstuff () {
  # This function just logs lines passed to it, but could do anything.
  local CURRENT_FUNC="logstuff"
  ##### INPUTS
  INPUTLINE="$*"
  #####

  log "DEBUG" "Input line: $INPUTLINE"
}

# Export all functions and variables that need to be available to subshells

export LOGFILE="${0}.log"
export LOGLEVEL="DEBUG"
export -f inarray
export -f pprint
export -f log
export -f logstuff

main () {
  local CURRENT_FUNC="main"
  echo -e echo\ {1..10}\ \>\>\ thread.out\\n > "$FIFO_PARALLEL"
  echo "logstuff 'whoop' &>> thread.out" > "$FIFO_PARALLEL"
  find . -maxdepth 1 -type f -exec echo "logstuff 'Found file: {}'" \; > "$FIFO_PARALLEL"
}

main

exit

# This is how you loop over all filenames in a directory in a linear fashion
log "INFO" "Doing linear example"
while read -r LINE ; do
  # Log the line and strip any leading ./
  logline "${LINE#./}"
done <<< "$(find . -maxdepth 1 -type f)"
# Notice how we are using reverse redirection of a subshell to feed the loop at the end.
# We could do a forward pipe with `find | while read`, but
# this would result in the whole while loop living in a subshell.
# Because of this, that subshell wouldn't be able to pass variables back up to the main script,
# nor would failures/exit commands within properly kill the parent script.
# Using reverse redirection from a limited subshell like this maintains variable scoping.

# This is how you do the same thing, but instead feed the commands to GNU Parallel (if you have it installed)
if which parallel > /dev/null ; then
    log "INFO" "Doing parallel example"
    find . -maxdepth 1 -type f\
      | parallel logline ::: {}
else
    log "WARN" "GNU Parallel is not installed"
fi
# Notice how we are doing it the "normal" way here. Since GNU Parallel will be in a subshell anyway, the pipe method is more readable.
# Just remember that you have to be extra careful about variable scoping this way.
