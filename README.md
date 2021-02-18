# Watcher
This script watches for changes in a given directory then runs a specified command.

## Features
* Runs as singleton, that is, if another process tries to run a second instance watcher.sh issues a message saying it is already running and exits.
* Runs the specified command and will not start another until it finishes.
* Runs like a daemon, roughly every second it checks to see if there is a process running, and if not, if there are more files to process.

## Commands
Possible commands are:
* run - check the supplied directories for file types.
* stop - stops watcher.sh and does clean up of its PID file. Also prevents the service from being restarted if you want it to be turned off.

## watcher directory
A watcher directory is created in the diretory to be watched. watcher.sh looks for a watcher.cmd file there, and will record its pid and 
child process pids in watcher/locks.

## Failed directory
The user is expected to specify a directory where it will put the input files of the script that returned a non-zero exit status.

## locks directory
The process id of the currently running child process can be found here in the watcher/locks directory. Any residual pid files found in that directory will be removed when watcher.sh starts.

# Instructions for running
Watcher.sh can be run from either the command line or cron. When it starts it looks for the following.
1) echo run >> ~/watcher/watcher.cmd
2) Set your directory and file types to watch.
3) Set the script to run.
4) Stop the process with echo stop >> ~/watcher/watcher.cmd. 

This will stop watcher.sh from starting up. Delete the stop command, or echo run into the file once more, and you or cron can run watcher.sh again.
