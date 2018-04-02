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
  # Set the name of this function for the logger
  local CURRENT_FUNC="main"
  # Log a test message
  log_info "Starting tasks"
  # Run the example function
  example_function stuff things
  # Log a message that shows a variable
  log_debug "EXAMPLEVAR = ${EXAMPLEVAR}"
  # Use find to create commands to run in parallel
  find ./ -maxdepth 1 -type f -exec echo Found file {} \; | prunner -c echo
  # ...
}

# Run main and pass it the arguments from your shell
main "$@"
quit 'INFO' 'All tasks completed successfully'
