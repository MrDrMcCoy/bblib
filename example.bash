#!/bin/bash

# Import the lib
source extlib.bash
# sourcing example.bash.conf is implied if it exists

# Read the default command line arguments
argparser "$@"

# Ensure only one instance of this script is running
checkpid

# Validate that the correct user is running this script per the config
requireuser

# Add task to run on exit
FINALCMDS+=("example_finally")

#####
# If you wish to propagate variables and functions to subshells or GNU Parallel, you will need to export them like so:
#     export VARIABLE_NAME
#     export -f FUNCTION_NAME
#####

main () {
  #####
  # Put your actions here! It is good practice to keep all logic in functions where possible
  #####
  local CURRENT_FUNC="main"
  log_info "Starting tasks"
  example_function stuff things
  log_debug "EXAMPLEVAR = ${EXAMPLEVAR}"
  # ...
}

# Run main
log 'INFO' 'Starting main...'
main
quit 'INFO' 'All tasks completed successfully'
