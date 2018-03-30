# bblib

The _"Better BASH Library"_: A set of functions to assist with creating well-written and reliable BASH scripts. The functions are documented in-line within `bblib.bash`, and a simple example that uses it is in `example.bash`.

## Usage

Add this to the top of your BASH script:

```bash
source <(wget -qO- https://raw.githubusercontent.com/MrDrMcCoy/bblib/1.1.4/bblib.bash)
```

Alternately, clone this repo locally and use `source` with the full path to `bblib.bash`.

Once `bblib.bash` is sourced in your script, you may refer to any of its supplied functions and/or replace them with your own.

## General Info

- This library will automatically source any shell script that is named `${0}.conf` (Example: `yourscript.conf` or `yourscript.sh.conf`). This is the recommended way to add or replace variables and functions outside your main script.
- This library sets the shell to exit on the first error from a command or pipe. This ensures safer execution and better debugging.
- The library will set a trap for SIGINT and SIGTERM to allow you to kill it should a command behave undesirably.
- It will set an additional trap that runs on exit to assist with mandatory cleanup. See the `finally` function for more details.

## Function breakdown

- `usage`
  - Description: Prints help and usage info
  - Usage: `usage`
  - Notes: This is just an example. You should replace this with a similar function in your sourced conf file or in your main script.
- `pprint`
  - Description: Properly line-wraps text that is piped in to it. It tries to auto-detect your terminal width, which can be set manually as the first argument, and has a hard fallback of 80.
  - Usage:
    - `command | pprint [options]`
    - `pprint [options] <<< "text"`
  - Options:
    - `[0-7]|[COLOR`]: Prints the ASCII escape code to set color.
    - `[bold]`: Prints the ASCII escape code to set bold.
    - `[underline]`: Prints the ASCII escape code to set underline.
  - Notes: More info here: <http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x405.html>
- `inarray`
  - Description: Checks to see if a string is in an array and returns the index if true.
  - Usage: `inarray "${ARRAY[@]}" "SEARCHSTRING"`
- `uc`
  - Description: Converts text to uppercase.
  - Usage:
    - `command | uc`
    - `uc [text]`
- `lc`
  - Description: Converts text to lowercase.
  - Usage:
    - `command | lc`
    - `lc [text]`
- `hr`
  - Description: Prints a horizontal rule.
  - Usage:
    - `hr`
    - `hr $CHARACTER`
- `log`
  - Description: Formats log messages and writes them to syslog, stderr, and a file.
  - Usage:
    - `command |& log [severity]`
    - `log [severity] [message]`
  - Aliases:
    - `log_debug` = `log "DEBUG"`
    - `log_info` = `log "INFO"`
    - `log_note` = `log "NOTICE"`
    - `log_warn` = `log "WARN"`
    - `log_err` = `log "ERROR"`
    - `log_crit` = `log "CRITICAL"`
    - `log_alert` = `log "ALERT"`
    - `log_emer` = `log "EMERGENCY"`
  - Variables:
    - LOGLEVEL: The cutoff for message severity to log (Default is INFO).
    - LOGFILE: Path to a log file to write messages to (Default is to skip file logging).
    - TRACEDEPTH: Sets how many function levels above this one to start a stack trace (Default is 1).
  - Notes:
    - This function depends on the `inarray`, `pprint`, and `uc` functions.
    - Logging to file requires `$LOGFILE` to be set.
    - The default log level is _INFO_ if you do not define it.
    - The default severity is _NOTICE_ if you do not define it.
    - Valid levels/severities are _EMERGENCY, ALERT, CRITICAL, ERROR, WARN, NOTICE, INFO, DEBUG_ as per `syslog`. Other severities will numerically equate to NOTICE in `syslog`.
    - All interactive output is color-coded via pprint.
- `quit`
  - Description: Logs a message and exits
  - Usage: `quit [severity] [message] [exitcode]`
- `argparser`
  - Description: Parses flags passed on the command-line
  - Usage: `argparser "$@"`
  - Notes: This function is meant to be copied into your sourced conf file and modified to suit your script's needs.
- `requireuser`
  - Description: Checks to see if the user running the script matches the desired username and exits on failure.
  - Usage: `requireuser [user]`
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
- `prunner`
  - Description: Executes commands in parallel.
  - Usage:
    - `prunner -t [threads] -c [command] [files...]`
    - `prunner [commandline] [commandline...]`
    - `commandline_generator | prunner`
    - `find . -name "*.txt" | prunner -c "gzip -v" -t 8`
  - Arguments:
    - `-c`: Command to prepend to each job line. If you do `-c gzip` and pipe in to or suffix `prunner` with arguments, the resulting background command will be `gzip $JOBLINE`.
    - `-t`: Threads to use. Default is 8. You can alternately set the `THREADS` environment variable.
  - Notes: The number of jobs to run concurrently may also be set by the `THREADS` variable.

## Variables

- `FINALCMDS`
  - Description: Array containing commands to run on exit. Add actions to its list by running: `FINALCMDS+=("command arg arg")`
  - Used by: `finally`.
  - Default: ()
- `LOCAL_HISTORY`
  - Description: Array containing every command that is run by the script. It is populated by a DEBUG trap.
  - Default: ()
  - Used by: `log`
- `LOGLEVEL`
  - Description: Set this to determine the cutoff for logging severity according to the levels in `syslog`.
  - Used by: `log`.
  - Notes: Valid levels are _EMERGENCY, ALERT, CRITICAL, ERROR, WARN, NOTICE, INFO, DEBUG_.
  - Default: 'INFO'
- `LOGFILE`
  - Description: Set this to have `log` additionally output to a file.
  - Used by: `log`.
  - Notes: This will capture debug output if BASH has `set -x`.
  - Default: _unset_
- `PIDFILE`
  - Description: The path to a file for tracking the PID of the script.
  - Used by: `checkpid`.
  - Default: '${0}.pid'
- `REQUIREUSER`
  - Description: Variable to set the user that is allowed to run this script.
  - Used by: `requireuser`.
  - Default: _unset_
- `SCRIPT_NAME`
  - Description: The name of the script that will appear in the header of all log lines.
  - Used by: `log`.
  - Default: "${0}"
- `THREADS`
  - Description: Integer to control the number of background jobs to allow at once.
  - Used by: `prunner`.
  - Default: 8
- `TRACEDEPTH`
  - Description: How many function levels above `log` to start printing stack trace messages.
  - Default: 1
  - Used by: `log`

## Dependencies

The commands that `bblib.bash` calls out to are listed here, in case you are on a system that does not have them:

- `cat`
  - Used by: `usage`
- `fold`
  - Used by: `pprint`
- `logger`
  - Used by: `log`
- `tee`
  - Used by: `log`
- `tr`
  - Used by: `uc`, `lc`, `log`
- `tput`
  - Used by: `pprint`

## Resources

If you would like to extend this library, some resources for advanced usage are available here:

- The BASH Beginners Guide, which is not just for beginners: <https://www.tldp.org/LDP/Bash-Beginners-Guide/html/>
- The Advanced BASH guide: <http://tldp.org/LDP/abs/html/>
- The BASH Hackers Wiki has great advanced usage description and examples for BASH: <http://wiki.bash-hackers.org/>
- BASH Style Guide: <https://google.github.io/styleguide/shell.xml>
- A very good `getopts` tutorial: <https://sookocheff.com/post/bash/parsing-bash-script-arguments-with-shopts/>
