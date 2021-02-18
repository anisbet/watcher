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

. ~/.bashrc

# Prints out usage message.
usage()
{
    cat << EOFU!
 Usage: $0 [flags]

Monitors a given directory for files and if found executes a script with the file name as parameter.

Watcher.sh can be run from either the command line or cron. When it starts it looks for the following.
1) Set your directory and file types to watch with --dir=/foo/bar/*.flat
2) echo run >> /foo/bar/watcher/watcher.cmd
3) Set the script to run on the files with --script=/fizz/buzz.sh
4) Run $0 on command line, or by cron.
4) Stop the process with echo stop >> /foo/bar/watcher/watcher.cmd

If the watcher.cmd file contains stop, cron will not be able to run watcher.sh.

Flags:
-d, -dir, --dir [/foo/bar/*.flat]: Specifies the file types to watch for in the directory.
-h, -help, --help: This help message.
-s, -script, --script [/foo/bar.sh]: Specifies the script to run when files appear in the path
 denoted by --dir.
-t, -test, --test: Display debug information to STDOUT.
-v, -version, --version: Print script version and exits.
 Example:
    ${0} --dir=/home/user/dir/*.txt --script=/home/user/bin/cleanup.sh
EOFU!
}

##### Non-user-related variables ########
export VERSION=0.2
export which_script=''
export watch_dir=''
export is_test=false

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "dir:,help,script:,test,version" -o "d:hs:tv" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"

while true
do
    case $1 in
    -d|--dir)
        shift
        export watch_dir="$1"
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    -s|--script)
        shift
        export which_script="$1"
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
: ${which_script:?Missing -s,--script} ${watch_dir:?Missing -d,--dir}

# Test if the script we want to run actually exists.
# If the script does not at least 755 permissions -x will fail.
if [[ ! -x "$which_script" ]]; then
    echo "Error: could not find $which_script or it may not be executable." >&2
    exit 1
fi

# Make a directory where we store the command and pids of child processes.
WATCHER_DIR_BASE=$(dirname "$watch_dir")
WATCHER_DIR=$WATCHER_DIR_BASE/watcher
# The command to run should be the first non-commented line is the command file.
# Possible commands are:
#  * run - check the supplied directories for flat files and if found load them.
#  * stop - Stop checking, clean up any child processes and exit.
COMMAND_FILE=$WATCHER_DIR/watcher.cmd
LOCK_DIR=$WATCHER_DIR/locks
if [ ! -d "$LOCK_DIR" ]; then
    echo "creating $WATCHER_DIR"
    mkdir -p $LOCK_DIR
fi

# Save the PID of the script to a pid file, and remove it on exit.
# If another instance tries to run while this one is running exit.
my_pid_file=$WATCHER_DIR/watcher.pid
if [ -f "$my_pid_file" ]; then
    other_running_pid=$(cat $my_pid_file)
    echo "Script is already running [process ${other_running_pid}]"
    echo "It can be gracefully stopped by appending 'stop' to $COMMAND_FILE "
    exit 0
else
    # Create a file with current PID to indicate that process is running.
    echo $$ > "$my_pid_file"
    # If we are starting clean up any locks from previous processes.
    if ls "$LOCK_DIR/*" 2>/dev/null; then rm "$LOCK_DIR/*"; fi
fi
# on exit remove the pid file as part of clean up.
# lock files in $LOCK_DIR may be diagnostic so leave them there until next run.
trap 'rm -f "$my_pid_file"' EXIT
# If the process is killed with ctrl-c the script will exit and the above
# trap will also fire.
trap 'ls -laR $WATCHER_DIR; exit 1' SIGINT

######### load user function ##########
run_command()
{
    local my_file=''
    # Look for new files in the given directory, but there may not be any.
    ls $watch_dir 2>/dev/null | while read my_file
    do
        local time=$(date +"%Y-%m-%d %H:%M:%S")
        # Test the output of the script and log result.
        # It is the scripts responsibility to move or 
        # modify files so they do not get re-run.
        if $which_script $my_file; then
            echo "[$time] $my_file loaded successfully"
        else
            echo "[$time] FAILED to load $my_file" 
        fi
    done
}



# Start an infinite loop but check each time for a command file and read it
# to see if the user wants the service to shutdown it down.
while true; do
    if [ ! -r "$COMMAND_FILE" ]; then 
        echo "Error: $COMMAND_FILE file not found, exiting." 2>&1
        exit 1
    else
        # Find the command which is the last non-commented line.
        CMD_STR=$(egrep -ve '^#' $COMMAND_FILE | tail -1)
        if [ -z "$CMD_STR" ]; then
            echo "Error: no command read from $COMMAND_FILE Exiting." 2>&1
            exit 2
        fi
    fi

    # Now test the command read from file.
    case $CMD_STR in
        r|run)
            # Check if the previous process is still running and if it is back off
            if ls $LOCK_DIR/* >/dev/null 2>&1 ; then
                ls $LOCK_DIR/* | while read running_process
                do
                    old_pid=$(basename $running_process)
                    if ! pgrep --parent "${old_pid}" >/dev/null 2>&1 ; then
                        rm $running_process
                        [[ "$is_test" == true ]] && echo "process $old_pid finished"
                    fi
                done
            else
                # read the flat file directories, from the watcher.cmd file
                # and look for flat files in those directories.
                run_command &
                pid=${!}
                touch $LOCK_DIR/$pid
                [[ "$is_test" == true ]] && echo "starting process: $pid"
            fi
            ;;
        s|stop)
            echo "stop  [$COMMAND_FILE]"
            exit 0
            ;;
        *)
            echo -e "Error: garbled command [$COMMAND_FILE].\nSee --help for more information, exiting." >&2
            exit 1
            ;;
    esac
    sleep 1
done
