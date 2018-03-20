#!/bin/bash

# Import bbblib
source ../bblib.bash

main () {
  local CURRENT_FUNC="main"
  log "DEBUG" "Starting tests"

  # Test argparser
  argparser -v
  # Disable bash debugging
  set +x
  argparser -s test.conf
  argparser -s || true &
  argparser -y || true &
  argparser -h

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
  requireuser || true &
  requireuser n00b || true &
  requireuser "$USER"
  unset REQUIREUSER
  requireuser || true &

  # Generate test files
  for f in random{0..32} ; do
    dd if=/dev/random bs=1M count=1 | base64 > $f.out
  done

  # Parallel test
  prunner -c "gzip -vk" *.out

  # Add cleanup tasks
  FINALCMDS+=('rm -v *.gz')
  FINALCMDS+=('rm -v *.out')

  quit "INFO" "All tests finished."
}

quit "ERROR" "Script reached end unexpecedtly!"
