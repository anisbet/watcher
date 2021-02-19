# Watcher
This script watches for changes in a given directory then runs an application.

Watcher runs on a one-second cycle called a tick, and any files that match --dir are passed, one-at-a-time to an application specified with the required --script flag. Watcher will back off until the helper application has finished each file before checking for new ones. 

This behaviour can be changed by spawning a child process for each application, but by default it is assumed that the application cannot run asynchronously, which is the safer bet.

Watcher can be run on different directories and file types, but only one watcher can watch any given directory. If another process tries to run a second instance in the same directory, watcher.sh displays a message with the running instance's pid and exits.

# Instructions for running
A watcher.sh job can be set up as follows.
1) Create a '/foo/bar/watcher' directory. If you forget, watcher will create one automatically.
2) Set the directory and file types to watch for: --dir='/foo/bar/*.txt'
3) Set watcher command to run: echo run >> /foo/bar/watcher/watcher.cmd 
4) Run watcher.sh with nohup or cron or what-have-you.
5) Stop watcher.sh with: echo stop >> /foo/bar/watcher/watcher.cmd 

**NOTE: The stop command prevents everyone from running watcher on /foo/bar.**

## Commands
Possible commands are:
* run - check the supplied directories for file types.
* stop - stops watcher.sh and does clean up of its PID file. Also prevents the service from being restarted if you want it to be turned off.
* '#' - Lines that start with a hash '#' are comments and are ignored.
* You can append commands in a long list if you like because watcher only obeys the last non-commented command. In a panic you can clobber or append a command to the watcher.cmd file.

## watcher directory
A watcher directory is created in the directory to be watched. watcher.sh looks for a watcher.cmd file there, and will record its pid and 
child process pids in watcher/locks.

## Helper application
Watcher will call an application with the discovered file's name as an argument. That application is responsible for moving or renaming the files if you want to avoid watcher from re-processing them.

## locks directory
The process id of the currently running child process can be found here in the watcher/locks directory. If watcher is not running, any residual pid-lock files found in watcher/locks will be cleaned up when watcher.sh restarts.