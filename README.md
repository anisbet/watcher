# Watcher
This bash script watches for changes in a given directory then runs an application. It can be run like a service where the user does not have privileges to start and stop services.

Watcher runs on a one-second cycle called a tick, and any files that match --dir are passed, one-at-a-time to an application specified with the required --app flag. Watcher assumed that the helper app runs synchronously and will back off until the it has finished each file before watcher.sh checks for new ones. This behaviour can be changed by running the helper as a background process.

Watcher can be run on different directories and file types, but only one watcher can watch any given directory. If another process tries to run a second instance in the same directory, watcher.sh displays a message with the running instance's pid and exits.

# Instructions for running
A watcher.sh job can be set up as follows.
1) Create a '/foo/bar/watcher' directory. If you forget, watcher will create one automatically.
2) Add 'run' command to watcher.cmd. 
3) Run watcher.sh with command line, nohup, cron or what-have-you.
4) To stop watcher add 'stop' to the watcher.cmd file. 

**NOTE: The stop command in a given watcher.cmd file prevents everyone from running that instance of watcher.**

## Example
To watch for '*.txt' files in directory '/foo/bar':
`$ mkdir -p /foo/bar/watcher`
`$ echo run >> /foo/bar/watcher/watcher.cmd`
`$ nohup ./watcher.sh --dir=/foo/bar/*.txt --app=/app/path/app.sh`
...
When you want the watcher to stop:
`$ echo stop >> /foo/bar/watcher/watcher.cmd`

## Commands
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