# bash_template

A starting point for well-written and reliable BASH scripts. The functions are documented in-line within `extlib.bash`, and a simple example that uses it is in `example.bash`.

## General Info

- This library will automatically source any shell script that is named `${0}.conf` (Example: `yourscript.conf` or `yourscript.sh.conf`). This is the recommended way to add or replace variables and functions outside your main script.
- This library sets the shell to exit on the first error from a command or pipe. This ensures safer execution and better debugging.
- A few defaults are set that you are expected to update with better alterenatives:
  - `PIDFILE="/tmp/${0}.pid"` Should probably be changed to `PIDFILE="/var/run/${0}.pid` in `${0}.conf`
  - `LOGFILE="/tmp/${0}.log"` Should probably be changed to `LOGFILE="/var/log/${0}.log` in `${0}.conf`
- The library will set a trap for SIGINT and SIGTERM to allow you to kill it should a command behave undesirably.
- If you use the `bash4funcs` function, it will set an additional trap that runs on exit to assist with mandatory cleanup. See the `finally` function for more details.

## Function breakdown

- `usage`
  - Description: Prints help and usage info
  - Usage: `usage`
  - Notes: You should replace this with a similar function in your sourced conf file or in your main script.
- `pprint`
  - Description: Properly line-wraps text that is piped in to it
  - Usage: `command | pprint` or `pprint <<< "text"`
- `log`
  - Description: Formats log messages and writes them to stderr and a file
  - Usage: `command |& log [SEVERITY]` or `log [SEVERITY] "message"`
  - Aliases:
    - `log_debug` = `log "DEBUG"`
    - `log_info` = `log "INFO"`
    - `log_warn` = `log "WARN"`
    - `log_err` = `log "ERROR"`
- `quit`
  - Description: Logs a message and exits
  - Usage: `quit [SEVERITY] "message"`
- `argparser`
  - Description: Parses flags passed on the command-line
  - Usage: `argparser "$@"`
  - Notes: This function is meant to be copied into your sourced conf file and modified to suit your script's needs.
- `bash4funcs`
  - Description: Enables functions that depend on BASH version >= 4
  - Usage: `bash4funcs`
  - Sub-functions:
    - `finally`
      - Description: A function that runs extra commands before the script exits
      - Usage: Add actions to its list by running: `FINALCMDS+=("command arg arg")`
    - `checkpid`
      - Description: Checks to see if another copy of this script is running by maintaining a PID file
      - Usage: `checkpid`
      - Notes: This function only works properly in Linux, as it depends on PROCFS.

## Resources

If you would like to extend this script, some resources for advanced usage are available here:

- The BASH Beginners Guide, which is not just for beginners: https://www.tldp.org/LDP/Bash-Beginners-Guide/html/
- The Advanced BASH guide: http://tldp.org/LDP/abs/html/
- The Bash Hackers Wiki has great advanced usage description and examples for BASH: http://wiki.bash-hackers.org/
- BASH Style Guide: https://google.github.io/styleguide/shell.xml
