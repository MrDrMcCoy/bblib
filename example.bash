#!/bin/bash

## before including any other files, be sure we are able qualify the path to the file properly

# Import the useful libs
source "${0%/*}/extlib.bash"

# Optionally import additional configs and functions
# source your-stuff.bash

#####
# Put your actions here!
#####
log_info 'Starting tasks'
# ...
quit 'INFO' 'All tasks completed successfully'

# fin
# always exit
exit 0
