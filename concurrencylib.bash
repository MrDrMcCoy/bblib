#!/bin/bash

# Create FIFO for thread-safe logging
FIFO_LOGWRITER="${FIFO_LOGWRITER:-${0}.fifo.logwriter}"
if [ ! -p "$FIFO_LOGWRITER" ] ; then
  if mkfifo "$FIFO_LOGWRITER" |& log "DEBUG" ; then
    FINALCMDS+=("rm -fv '$FIFO_LOGWRITER'")
    export FIFO_LOGWRITER
    cat < "$FIFO_LOGWRITER" > "$LOGFILE" |& log "DEBUG" &
    log "DEBUG" "FIFO opened for logging: $FIFO_LOGWRITER"
  else
    log "ERROR" "FIFO could not be created: $FIFO_LOGWRITER"
  fi
else
  log "ERROR" "FIFO already exists: $FIFO_LOGWRITER"
fi

# Create FIFO for parallel job execution
export SHELL=$(type -p bash)
FIFO_PARALLEL="${FIFO_PARALLEL:-${0}.fifo.paralel}"
if [ ! -p "$FIFO_PARALLEL" ] ; then
  if mkfifo "$FIFO_PARALLEL" |& log "DEBUG" ; then
    FINALCMDS+=("rm -fv '$FIFO_PARALLEL'")
    log "DEBUG" "FIFO opened for parallel: $FIFO_PARALLEL"
    if which parallel &> /dev/null ; then
      parallel "${PARALLEL_ARGS[@]}" < "$FIFO_PARALLEL" |& log "DEBUG" &
    else
      quit "ERROR" "Could not find GNU Parallel, exiting."
    fi
  else
    log "ERROR" "FIFO creation failed: $FIFO_PARALLEL"
  fi
else
  log "ERROR" "FIFO for Parallel already exists: $FIFO_PARALLEL Refusing to start new instance of parallel."
fi
