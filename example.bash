#!/bin/bash

# Import the lib
source extlib.bash

# Run some of the functions to help with startup
argparser "$@"
checkpid
requireuser

# Optionally import additional configs and functions
# source your-stuff.bash

# Set tasks to run on exit
FINALCMDS+=("example_finally")

#####
# If you wish to propagate variables and functions to subshells or GNU Parallel, you will need to export them like so:
#     export VARIABLE_NAME
#     export -f FUNCTION_NAME
#####

#####
# Put your actions here!
#####
log_info "Starting tasks"
example_function stuff things
log_debug "EXAMPLEVAR = ${EXAMPLEVAR}"
# ...
quit 'INFO' 'All tasks completed successfully'
