#!/bin/bash

# Import the useful libs
source extlib.bash

# Run some of the functions to help with startup
argparser
checkpid

# Optionally import additional configs and functions
# source your-stuff.bash

#####
# Put your actions here!
#####
log_info 'Starting tasks'
example_func stuff things
# ...
quit 'INFO' 'All tasks completed successfully'
