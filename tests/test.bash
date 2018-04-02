#!/bin/bash

# Import bbblib
source ../bblib.bash

main () {
  truncate -s 0 "${LOGFILE:-bblib_test.log}"

  log "INFO" "Starting tests"

  # Test argparser
  log "INFO" "Test argparser with no options"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser' || true
  log "INFO" "Test argparser -h"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -h' || true
  log "INFO" "Test argparser -v"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -v' || true
  log "INFO" "Test argparser -s test.bash.conf"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -s test.bash.conf' || true
  log "INFO" "Test argparser -s"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -s' || true
  log "INFO" "Test argparser -y"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; argparser -y' || true

  # Test hr
  log "INFO" "Test hr"
  hr
  hr =

  # Test lc, uc, pprint line wrapping
  log "INFO" "Test lc"
  head -n1 lorem-ipsum.txt | lc | pprint
  log "INFO" "Test uc"
  tail -n1 lorem-ipsum.txt | uc | pprint

  # Test pprint colors
  log "INFO" "Test pprint"
  pprint 0 <<< black
  pprint 1 <<< red
  pprint 2 <<< green
  pprint 3 <<< yellow
  pprint 4 <<< blue
  pprint 5 <<< magenta
  pprint 6 <<< cyan
  pprint 7 <<< white
  pprint 8 <<< bold
  pprint 9 <<< underline

  # Test shorthand log log loggers
  log_debug "shorthand log_debug test"
  log_info "shorthand log_info test"
  log_note "shorthand log_note test"
  log_warn "shorthand log_warn test"
  log_err "shorthand log_err test"
  log_crit "shorthand log_crit test"
  log_alert "shorthand log_alert test"
  log_emer "shorthand log_emer test"

  # Test for bash 4
  log "INFO" "Test bash4check"
  bash4check

  # Pid check
  log "INFO" "Test checkpid"
  checkpid || true
  log "INFO" "Test checkpid in second shell"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; checkpid' || true

  # User check
  log "INFO" "Test requireuser with \$REQUIREUSER"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; requireuser' || true
  log "INFO" "Test requireuser without \$REQUIREUSER"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; unset REQUIREUSER ; requireuser' || true
  log "INFO" "Test requireuser n00b"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; requireuser n00b' || true
  log "INFO" "Test requireuser with current user"
  bash -c 'source ../bblib.bash ; source test.bash.conf ; requireuser "$USER"' || true

  # Generate test files
  log "INFO" "Generating test files"
  RDATA="$(dd if=/dev/random bs=8k count=1 2> /dev/null)"
  for f in random{0..32}.out ; do
    base64 <<< "$RDATA" > $f
  done

  # Parallel test
  log "INFO" "Test prunner gzipping the .out files with arguments for the jobs"
  prunner -c "gzip -fk" *.out
  log "INFO" "Test prunner echoing the .out files with stdin for the jobs"
  find . -maxdepth 1 -type f -name "*.out" | head -n5 | prunner -c "echo found file " -t 6

  # Add cleanup tasks
  FINALCMDS+=('rm -v *.out')
  FINALCMDS+=('rm -v *.gz')

  false
}

main "$@"

quit "ERROR" "Script reached end unexpecedtly!"
