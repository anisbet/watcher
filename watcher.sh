#!/bin/bash
###############################################################################
#
# watcher.sh watches for new files in a set of directores.
# 
#  Copyright 2021 Andrew Nisbet
#  
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#  
#       http://www.apache.org/licenses/LICENSE-2.0
#  
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Wed 17 Feb 2021 10:26:29 AM EST
#
###############################################################################
set -o pipefail

. ~/.bashrc

# Prints out usage message.
usage()
{
    cat << EOFU!
 Usage: $0 [flags]

Monitors a given directory for files and if found executes an application 
with the file name as parameter.

Watcher.sh can be run from either the command line or cron, and a watch job 
for files in '/foo/bar/*.txt' can be set up as follows.
1) Create a '/foo/bar/watcher' directory. If you forget, watcher 
   will create one automatically.
2) Set the directory and file types to watch for: --dir='/foo/bar/*.txt'
3) Set watcher command to run: echo 'run' >> /foo/bar/watcher/watcher.cmd 
4) Stop the process with: echo 'stop' >> /foo/bar/watcher/watcher.cmd

**NOTE: The stop command prevents everyone from running watcher on the directory
being watched, in this case /foo/bar. This stops unseen processes like forgotten
crontab tasks from trying to start a watcher.

Also note, 'run', 'Run', and 'RUN' are equivalent, as are 'stop', 'Stop', and 'STOP'.

Flags:
-a, -app, --app [/foo/bar.sh]: Specifies the application to run when files appear in the path
 denoted by --dir.
-d, -dir, --dir [/foo/bar/*.flat]: Specifies the file types to watch for in the directory.
-h, -help, --help: This help message.
-n, -no_loop, --no_loop: Lets the helper app loop through the new files with no file parameter.
    watcher will back off until it has completed all it's files.
-t, -test, --test: Display debug information to STDOUT.
-v, -version, --version: Print watcher.sh version and exits.
 Example:
    ${0} --dir=/home/user/dir/*.txt --app=/home/user/bin/cleanup.sh
EOFU!
}

##### Non-user-related variables ########
export VERSION=1.2.5
export application=''
export watch_dir=''
export is_test=false
# Default true: watcher.sh starts an instance of the helper app for each new file found.
#        false: watcher.sh starts an instance of the helper app to process all new files.
export use_file_loop=true

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "app:,dir:,help,no_loop,test,version" -o "a:d:hntv" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
do
    case $1 in
    -a|--app)
        shift
        export application="$1"
        ;;
    -d|--dir)
        shift
        export watch_dir="$1"
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    -n|--no_loop)
        export use_file_loop=false
        ;;
    -t|--test)
        export is_test=true
        ;;
    -v|--version)
        echo "$0 version: $VERSION"
        exit 0
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done
# Sed file, input file names, and git branch name are all required.
: ${application:?Missing -a,--app} ${watch_dir:?Missing -d,--dir}
# Make a directory where we store the command and pids of child processes.
WATCHER_DIR_BASE=$(dirname "$watch_dir")
WATCHER_DIR=$WATCHER_DIR_BASE/watcher
## Set up logging.
LOG_FILE="$WATCHER_DIR/watcher.log"
# Logs messages to STDERR and $LOG file.
# param:  Log file name. The file is expected to be a fully qualified path or the output
#         will be directed to a file in the directory the script's running directory.
# param:  Message to put in the file.
# param:  (Optional) name of a operation that called this function.
logit()
{
    local message="$1"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    if [ -t 0 ]; then
        # If run from an interactive shell message STDERR.
        echo -e "[$time] $message" >&2
    fi
    echo -e "[$time] $message" >>$LOG_FILE
}

# The command to run should be the first non-commented line is the command file.
# Possible commands are:
#  * run - check the supplied directories for flat files and if found load them.
#  * stop - Stop checking, clean up any child processes and exit.
COMMAND_FILE=$WATCHER_DIR/watcher.cmd
LOCK_DIR=$WATCHER_DIR/locks
[ "$is_test" == true ] && logit "lock dir: $LOCK_DIR "
[ "$is_test" == true ] && logit "cmds dir: $COMMAND_FILE "
[ "$is_test" == true ] && logit "watch dir: $WATCHER_DIR "
if [ ! -d "$LOCK_DIR" ]; then
    logit "creating $WATCHER_DIR"
    mkdir -p "$LOCK_DIR"
fi

# Test if the application we want to run actually exists.
# If the application does not at least 755 permissions -x will fail.
if [ ! -x "$application" ]; then
    logit "Error: could not find $application or it may not be executable."
    exit 1
fi

# Save the PID of the script to a pid file, and remove it on exit.
# If another instance tries to run while this one is running exit.
my_pid_file=$WATCHER_DIR/watcher.pid
if [ -f "$my_pid_file" ]; then
    other_running_pid=$(cat $my_pid_file)
    # If there is no such process then remove the PID file and continue.
    if pgrep --parent "$other_running_pid" >/dev/null 2>&1 ; then
        if [ "$is_test" == true ]; then
            logit "Script is already running with process $other_running_pid"
        fi
        exit 0
    else
        logit "Found PID file for another watcher process ($other_running_pid) but no such process is running. Cleaning it up."
        rm $my_pid_file
    fi
fi
# Create a file with current PID to indicate that process is running.
echo $$ > "$my_pid_file"
# If we are starting clean up any locks from previous processes.
if ls "$LOCK_DIR/*" 2>/dev/null; then rm "$LOCK_DIR/*"; fi
logit "== watch version: $VERSION [watching: $WATCHER_DIR_BASE] [app: $application] [pid: $$] "

# on exit remove the pid file as part of clean up.
# lock files in $LOCK_DIR may be diagnostic so leave them there until next run.
trap 'rm -f "$my_pid_file"; if ls "$LOCK_DIR/*" 2>/dev/null; then rm "$LOCK_DIR/*"; fi; logit "Received SIGINT cleaning up and exiting."' EXIT
# If the process is killed with ctrl-c the script will exit and the above
# trap will also fire.
trap 'ls -laR $WATCHER_DIR; logit "Received SIGINT"; exit 1' SIGINT

######### load user function ##########
run_command()
{
    local my_file=''
    local time=''
    local my_message=''
    local my_filename=''
    # Look for new files in the given directory, but there may not be any.
    ls $watch_dir 2>/dev/null | while read my_file
    do
        # reset the output message
        my_message="watcher - app"
        case $use_file_loop in
        # Let the helper app loop through the new files.
        false)
            # Run the app without an argument.
            if $application; then
                my_message="$my_message status: SUCCESS"
            else
                my_message="$my_message status: FAILED" 
            fi
            logit "$my_message"
            # Return breaks out of the loop since all files are handled by app.
            return
            ;;
        # Default use this loop for each file as an argument to the app.
        true)
            # Run the app with the file as argument.
            my_filename=$(basename "$my_file")
            my_message="$my_message processed file: '$my_filename',"
            if $application $my_file; then
                my_message="$my_message status: SUCCESS"
            else
                my_message="$my_message status: FAILED"
            fi
            logit "$my_message"
            ;;
        esac
    done
}



# Start an infinite loop but check each time for a command file and read it
# to see if the user wants the service to shutdown it down.
while true; do
    if [ ! -r "$COMMAND_FILE" ]; then 
        logit "Error: $COMMAND_FILE file not found, exiting."
        exit 1
    else
        # Find the command which is the last non-commented line.
        CMD_STR=$(egrep -ve '^#' $COMMAND_FILE | tail -1)
        if [ -z "$CMD_STR" ]; then
            logit "Error: no command read from $COMMAND_FILE Exiting."
            exit 2
        fi
    fi

    # Now test the command read from file.
    case $CMD_STR in
        r|run|Run|RUN)
            # Check if the previous process is still running and if it is back off
            if ls $LOCK_DIR/* >/dev/null 2>&1 ; then
                ls $LOCK_DIR/* | while read running_process
                do
                    old_pid=$(basename $running_process)
                    if ! pgrep --parent "${old_pid}" >/dev/null 2>&1 ; then
                        rm $running_process
                        [ "$is_test" == true ] && logit "process $old_pid finished"
                    fi
                done
            else
                # read the flat file directories, from the watcher.cmd file
                # and look for flat files in those directories.
                run_command &
                pid=${!}
                touch $LOCK_DIR/$pid
                [ "$is_test" == true ] && logit "starting process: $pid"
            fi
            ;;
        s|stop|Stop|STOP)
            logit "Nothing to do, $COMMAND_FILE contains 'stop' command."
            if [ "$is_test" == true ]; then
                logit "To watch a directory add 'run' as the last line in $COMMAND_FILE and launch again."
                logit "See --help for more information, exiting."
            fi
            exit 0
            ;;
        *)
            logit "Error: garbled command $COMMAND_FILE.\nSee --help for more information, exiting."
            exit 1
            ;;
    esac
    sleep 1
done
