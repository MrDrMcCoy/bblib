#!/bin/bash

# Import bbblib
source ../bblib.bash
set -x
source "${0}.conf"
set +x

main () {
  local CURRENT_FUNC="main"
  log "DEBUG" "Starting tests"

  # Test argparser
  log "DEBUG" "Test argparser -h"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -h' || true
  log "DEBUG" "Test argparser -v"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -v' || true
  log "DEBUG" "Test argparser -s test.bash.conf"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -s test.bash.conf' || true
  log "DEBUG" "Test argparser -s"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -s' || true
  log "DEBUG" "Test argparser -y"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -y' || true

  # Test hr
  log "DEBUG" "Test hr ="
  hr =

  # Test lc, uc, and pprint
  log "DEBUG" "Test lc"
  lc < lorem-ipsum.txt | pprint > lorem-ipsum-lc-pprint.out |& log "DEBUG"
  log "DEBUG" "Test uc"
  uc < lorem-ipsum.txt | pprint > lorem-ipsum-uc-pprint.out |& log "DEBUG"

  # Test shorthand loggers
  log_debug "shorthand test"
  log_info "shorthand test"
  log_note "shorthand test"
  log_warn "shorthand test"
  log_err "shorthand test"
  log_crit "shorthand test"
  log_alert "shorthand test"
  log_emer "shorthand test"

  # Test for bash 4
  log "DEBUG" "Test bash4check"
  bash4check

  # Pid check
  log "DEBUG" "Test checkpid"
  checkpid
  log "DEBUG" "Test checkpid in second shell"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; checkpid' || true

  # User check
  log "DEBUG" "Test requireuser with \$REQUIREUSER"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; requireuser' || true
  log "DEBUG" "Test requireuser without \$REQUIREUSER"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; unset REQUIREUSER ; requireuser' || true
  log "DEBUG" "Test requireuser n00b"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; requireuser n00b' || true
  log "DEBUG" "Test requireuser with current user"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; requireuser "$USER"' || true

  # Generate test files
  log "DEBUG" "Generating test files"
  for f in random{0..32} ; do
    dd if=/dev/random bs=1M count=1 | base64 > $f.out &
  done
  wait

  # Parallel test
  log "DEBUG" "Test prunner gzipping the .out files"
  prunner -c "gzip -v" *.out

  # Add cleanup tasks
  #FINALCMDS+=('rm -v *.out')
  #FINALCMDS+=('rm -v *.gz')

  quit "INFO" "All tests finished."
}

main

quit "ERROR" "Script reached end unexpecedtly!"
