# bash_template

A starting point for well-written and reliable BASH scripts. The functions are documented in-line within `extlib.bash`, and a simple example that uses it is in `example.bash`.

## Usage

Add this to the top of your BASH script:

```bash
source <(wget -qO- https://raw.githubusercontent.com/MrDrMcCoy/bash_template/master/extlib.bash)
```

Alternately, clone this repo locally and use `source` with the full path to `extlib.bash`.

Once `extlib.bash` is sourced in your script, you may refer to any of its supplied functions and/or replace them with your own.

## General Info

- This library will automatically source any shell script that is named `${0}.conf` (Example: `yourscript.conf` or `yourscript.sh.conf`). This is the recommended way to add or replace variables and functions outside your main script.
- This library sets the shell to exit on the first error from a command or pipe. This ensures safer execution and better debugging.
- The library will set a trap for SIGINT and SIGTERM to allow you to kill it should a command behave undesirably.
- It will set an additional trap that runs on exit to assist with mandatory cleanup. See the `finally` function for more details.
- When defining additional functions, be sure to add `local CURRENT_FUNC="function_name"` to the beginning so that the log function can include it in the output for easier degugging.

## Function breakdown

- `usage`
  - Description: Prints help and usage info
  - Usage: `usage`
  - Notes: You should replace this with a similar function in your sourced conf file or in your main script.
- `pprint`
  - Description: Properly line-wraps text that is piped in to it
  - Usage: `command | pprint` or `pprint <<< "text"`
- `inarray`
  - Description: Checks to see if a string is in an array and returns the index if true.
  - Usage: `inarray "${ARRAY[@]}" "SEARCHSTRING"`
- `uc`
  - Description: Converts text to uppercase.
  - Usage: `command | uc` or `uc "text"`
- `lc`
  - Description: Converts text to lowercase.
  - Usage: `command | lc` or `lc "text"`
- `hr`
  - Description: Prints a horizontal rule.
  - Usage: `hr` or `hr $CHARACTER`
- `log`
  - Description: Formats log messages and writes them to syslog, stderr, and a file.
  - Usage: `command |& log "SEVERITY"` or `log "SEVERITY" "message"`
  - Aliases:
    - `log_debug` = `log "DEBUG"`
    - `log_info` = `log "INFO"`
    - `log_warn` = `log "WARN"`
    - `log_err` = `log "ERROR"`
  - Notes:
    - This function depends on the `inarray` and `uc` functions.
    - Logging to file requires `$LOGFILE` to be set.
    - The default severity is _INFO_ if you do not define it.
    - Valid severities are _EMERGENCY, ALERT, CRITICAL, ERROR, WARN, NOTICE, INFO, DEBUG_ as per `syslog`. Other severities will numerically equate to NOTICE, but the text will be passed through.
- `quit`
  - Description: Logs a message and exits
  - Usage: `quit "SEVERITY" "message"`
- `argparser`
  - Description: Parses flags passed on the command-line
  - Usage: `argparser "$@"`
  - Notes: This function is meant to be copied into your sourced conf file and modified to suit your script's needs.
- `requireuser`
  - Description: Checks to see if the user running the script matches the desired username and exits on failure.
  - Usage: `requireuser USER`
- `bash4check`
  - Description: Checks to see if you are on BASH 4.0 or above and exits if not.
  - Usage: Place `bash4check` at the beginning of any function that uses BASH 4+ features.
- `finally`
  - Description: A function that runs extra commands before the script exits
  - Usage: Add actions to its list by running: `FINALCMDS+=("command arg arg")`
- `checkpid`
  - Description: Checks to see if another copy of this script is running by maintaining a PID file
  - Usage: `checkpid`
  - Notes: This function only works properly in Linux, as it depends on PROCFS.

## Variables

- `CURRENT_FUNC`
  - Description: Set this variable in each function to inform the logger which function is emitting the message.
  - Default: 'SCRIPT_ROOT'
- `LOGLEVEL`
  - Description: Set this to determine the cutoff for logging severity according to the levels in `syslog`.
  - Notes: Valid levels are _EMERGENCY, ALERT, CRITICAL, ERROR, WARN, NOTICE, INFO, DEBUG_.
  - Default: 'INFO'
- `LOGFILE`
  - Description: Set this to have `log` additionally output to a file.
  - Notes: This will capture debug output if BASH has `set -x`.
  - Default: _unset_
- `PIDFILE`
  - Description: The path to a file for tracking the PID of the script if you call `checkpid`.
  - Default: '${0}.pid'
- `REQUIREUSER`
  - Description: Variable to set the user that is allowed to run this script if you call `requireuser`.
  - Default: _unset_
- `SCRIPT_NAME`
  - Description: The name of the script that will appear in the header of all log lines.
  - Default: "${0}"

## Resources

If you would like to extend this library, some resources for advanced usage are available here:

- The BASH Beginners Guide, which is not just for beginners: <https://www.tldp.org/LDP/Bash-Beginners-Guide/html/>
- The Advanced BASH guide: <http://tldp.org/LDP/abs/html/>
- The BASH Hackers Wiki has great advanced usage description and examples for BASH: <http://wiki.bash-hackers.org/>
- BASH Style Guide: <https://google.github.io/styleguide/shell.xml>
