# Watcher
This bash script watches for changes in a given directory then runs an application. It can be run like a service where the user does not have privileges to start and stop services.

Watcher checks for new files in `--dir` every second. If any are found the application specified with the required `--app` flag is called. By default watcher.sh passes each file match to the application sequentially, but `--no_loop` flag calls the application with no arguments. 

Watcher assumes that the helper app runs synchronously, and will not start a new one if one is already running. This behaviour can be changed by modifying the code to the helper application as a background process.

Watcher can be run on different directories and file types, but only one watcher can watch any given directory. If another process tries to run a second instance in the same directory, `watcher.sh` displays a message with the running instance's pid if a screen is attached, and exits.

Watcher and the app it runs, write to `STDOUT` and STDERR independently. If watcher is run without `STDOUT` attached, events are logged to `watcher/watcher.log`. This could complicate logging if watcher is run with `nohup` or a detactched screen session.

# Instructions for running
To set up a watcher job to say, check for new *.txt files in `/foo/bar` do the following.
1. Create a `/foo/bar/watcher` directory or optionally, watcher will create one for you. 

```bash
$ mkdir -p /foo/bar/watcher
```

1. Add 'run' command to /foo/bar/watcher/watcher.cmd. 'Run' and 'RUN' are also acceptable.
 
```bash
$ echo 'run' >> /foo/bar/watcher/watcher.cmd
```

1. Run watcher.sh from command line, cron or what-have-you.

```bash
$ echo 'run' >> /foo/bar/watcher/watcher.cmd;nohup ./watcher.sh --dir=/foo/bar/*.txt --app=/app/path/app.sh
```

1. To stop watcher add 'stop' to the watcher.cmd file. 'Stop' and 'STOP' are also acceptable.

```bash
$ echo 'stop' >> /foo/bar/watcher/watcher.cmd
```

## Cron-ing Watcher
On production `watcher` can be cronned to run frequently because if another watcher process is running on the same directory, the script will exit. [See  here for more information](#watcherpid-file).

`watcher` traps `SIGINT` (ctrl-C or `kill`) commands. When trapped, `watcher` will log the event and remove any locks in the locks dir, and its `PID` file.

In rare cases a `watcher` process can be killed before it can clean up its `PID`. If that happens any new `watcher` will check for the PID file _and_ if the process in the PID file is running.

If a `watcher` crashed, but didn't have time to clean up the PID file, and [a long time passes before `watcher` is re-run](#pids-reuse), there is a small chance that an unrelated process may be re-issued that PID. In that case the watcher script will back off until that process exits. If the process is a long running process, or the user's shell, the `watcher` could be waiting a long time. Running the `watcher` process frequently will ensure the process is restarted before the OS can re-issue the old PID to another process.
 
**NOTE: The stop command prevents any new watcher process in the directory.**

## Flags

- `-a`, `-app`, `--app` `[/foo/bar.sh]`: Specifies the application to run when files appear in the path denoted by --dir.
- `-d`, `-dir`, `--dir [/foo/bar/*.flat]`: Specifies the file types to watch for in the directory.
- `-h`, `-help`, `--help`: This help message.
- `-n`, `-no_loop`, `--no_loop`: Lets the helper app loop through the new files with no file parameter. watcher will back off until it has completed all it's files.
- `-t`, `-test`, `--test`: Display debug information to `STDOUT`.
- `-v`, `-version`, `--version`: Print watcher.sh version and exits.


## watcher directory
A watcher directory is created in the directory to be watched. watcher.sh looks for a `watcher.cmd` file there, will keep track of child process with `watcher/locks`, and log watcher activities in `watcher/watcher.log`.

## watcher.cmd Commands
Possible commands are:
* `run`, `Run` or `RUN` allows `watcher` to watch the named directorie for files.
* `stop`, `Stop` or `STOP` - stops `watcher.sh` from running, even if [the script is run by cron](#cron-ing-watcher). This prevents other user's or forgotten automation from restarting `watcher`.
* `#` - Lines that start with a hash `#` are comments and are ignored.
* You can append commands in a long list if you like because watcher only obeys the last non-commented command. In a panic you can clobber or append a command to the watcher.cmd file.

## watcher.pid File
The watcher process logs its PID in a file called `watcher/watcher.pid`. If a  PID file is found, and the process ID in the PID file is running, the watcher script will exit. If the PID file exists but there is no such process, the watcher script will log and remove the PID file and replace it with a new one for its own process. [See here for tips for cron-ing `watcher`](#cron-ing-watcher).

## Helper application
Watcher will call `--app` with each new file discovered as an argument. That application is responsible for moving or renaming the files if you want to avoid watcher from re-processing the new files.

## locks directory
The process id of the currently running child process can be found here in the` watcher/locks` directory. If watcher is not running, any residual pid-lock files found in `watcher/locks` will be cleaned up when `watcher.sh` restarts.

# Footnotes
## PIDs Reuse
The OS will issue a maximum of 4,194,304 PIDs before reusing old ones, so if the process can restart before the OS wraps around again, you're set.