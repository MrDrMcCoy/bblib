#!/bin/bash

# Import bbblib
source ../bblib.bash

main () {
  local CURRENT_FUNC="main"
  log "DEBUG" "Starting tests"

  # Test argparser
  bash -c 'source ../bblib.bash ; source test.conf ; argparser -h' || true
  bash -c 'source ../bblib.bash ; source test.conf ; argparser -v' || true
  bash -c 'source ../bblib.bash ; source test.conf ; argparser -s test.conf' || true
  bash -c 'source ../bblib.bash ; source test.conf ; argparser -s' || true
  bash -c 'source ../bblib.bash ; source test.conf ; argparser -y' || true

  # Test hr
  hr =

  # Test lc, uc, and pprint
  lc < lorem-ipsum.txt | pprint > lorem-ipsum-lc-pprint.out |& log "DEBUG"
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
  bash4check

  # Pid check
  checkpid
  bash -c 'source ../bblib.bash ; source test.conf ; checkpid' || true

  # User check
  bash -c 'source ../bblib.bash ; source test.conf ; requireuser' || true
  bash -c 'source ../bblib.bash ; source test.conf ; requireuser n00b' ||
  bash -c 'source ../bblib.bash ; source test.conf ; unset REQUIREUSER ; requireuser' || truetrue
  bash -c 'source ../bblib.bash ; source test.conf ; requireuser "$USER"' || true

  # Generate test files
  for f in random{0..32} ; do
    dd if=/dev/random bs=1M count=1 | base64 > $f.out &
  done
  wait

  # Parallel test
  prunner -c "gzip -v" *.out

  # Add cleanup tasks
  #FINALCMDS+=('rm -v *.out')

  quit "INFO" "All tests finished."
}

main

quit "ERROR" "Script reached end unexpecedtly!"
