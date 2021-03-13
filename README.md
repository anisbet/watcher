# Watcher
This bash script watches for changes in a given directory then runs an application. It can be run like a service where the user does not have privileges to start and stop services.

Watcher checks for new files in --dir every second. If any are found the application specified with the required --app flag is called, with each new file as an optional argument. Watcher assumed that the helper app runs synchronously and will back off until the it has finished each file before watcher.sh checks for new ones. This behaviour can be changed by modifying the code to the helper application as a background process.

Watcher can be run on different directories and file types, but only one watcher can watch any given directory. If another process tries to run a second instance in the same directory, watcher.sh displays a message with the running instance's pid and exits.

Watcher and the app it runs, write to STDOUT and STDERR independently. If watcher is run without STDOUT attached, events are logged to watcher/watcher.log. This could complicate logging if watcher is run with nohup or a detactched screen session.

# Instructions for running
To set up a watcher job to say, check for new *.txt files in /foo/bar do the following.
1. Create a '/foo/bar/watcher' directory or optionally, watcher will create one for you. 

```$ mkdir -p /foo/bar/watcher```shell

1. Add 'run' command to /foo/bar/watcher/watcher.cmd.
 
```$ echo run >> /foo/bar/watcher/watcher.cmd```shell

1. Run watcher.sh from command line, cron or what-have-you.

```$ echo run >> /foo/bar/watcher/watcher.cmd;nohup ./watcher.sh --dir=/foo/bar/*.txt --app=/app/path/app.sh```shell

1. To stop watcher add 'stop' to the watcher.cmd file.

```$ echo stop >> /foo/bar/watcher/watcher.cmd```shell
 
**NOTE: The stop command prevents any new watcher process in the directory.**

## Flags

- -a, -app, --app [/foo/bar.sh]: Specifies the application to run when files appear in the path denoted by --dir.
- -d, -dir, --dir [/foo/bar/*.flat]: Specifies the file types to watch for in the directory.
- -h, -help, --help: This help message.
- -n, -no_loop, --no_loop: Lets the helper app loop through the new files with no file parameter. watcher will back off until it has completed all it's files.
- -t, -test, --test: Display debug information to STDOUT.
- -v, -version, --version: Print watcher.sh version and exits.


## watcher.cmd Commands
Possible commands are:
* run - check the supplied directories for file types.
* stop - stops watcher.sh and does clean up of its PID file. Also prevents the service from being restarted if you want it to be turned off.
* '#' - Lines that start with a hash '#' are comments and are ignored.
* You can append commands in a long list if you like because watcher only obeys the last non-commented command. In a panic you can clobber or append a command to the watcher.cmd file.

## watcher directory
A watcher directory is created in the directory to be watched. watcher.sh looks for a watcher.cmd file there, will keep track of child process with watcher/locks, and log watcher activities in watcher/watcher.log.

## Helper application
Watcher will call --app with each new file discovered as an argument. That application is responsible for moving or renaming the files if you want to avoid watcher from re-processing the new files.

## locks directory
The process id of the currently running child process can be found here in the watcher/locks directory. If watcher is not running, any residual pid-lock files found in watcher/locks will be cleaned up when watcher.sh restarts.
