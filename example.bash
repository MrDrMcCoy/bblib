#!/bin/bash

# Import the useful libs
source extlib.bash

# Run some of the functions to help with startup
bash4-features
argparser
checkpid

# Optionally import additional configs and functions
# source your-stuff.bash

#####
# Put your actions here!
#####
log_info 'Starting tasks'
example_func stuff things
echo "EXAMPLEVAR = ${EXAMPLEVAR}"
# ...
quit 'INFO' 'All tasks completed successfully'
