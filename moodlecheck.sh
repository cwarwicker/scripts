#!/bin/sh

# Check that 2 arguments were passed
if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <path-to-moodle-repo> <path-to-check>"
	echo "E.g. $0 /var/www/html/moodle/ local/myplugin/"
	exit 1
fi

# Check that the first is a directory.
if ! [ -d "$1" ]; then
	echo "$1 is not a directory"
	exit 1
fi

INSTALL_PATH=${1%/}
CHECK_PATH=$INSTALL_PATH/${2%/}

INSTALL_CONFIG_PATH="${INSTALL_PATH}/config.php"
INSTALL_PLUGIN_PATH="${INSTALL_PATH}/local/moodlecheck"

LOG_PATH=$( echo ${2} | sed 's,[/.],_,g' ).log

PHP=$(whereis php | awk '{print $2}')

# Check that we specified a moodle repo in the install path.
if ! [ -e "$INSTALL_CONFIG_PATH" ]; then
	echo "No config file found at (${INSTALL_CONFIG_PATH}). Not a moodle repo."
	exit 1
fi

# Make sure the check_path exists.
if ! [ -e "$CHECK_PATH" ]; then
	echo "$CHECK_PATH does not exist."
	exit 1
fi

# Check if we need to install the local_moodlecheck plugin.
if [ -d "$INSTALL_PLUGIN_PATH" ]; then
	echo "local_moodlecheck plugin already installed..."
else
	echo "Installing local_moodlecheck plugin..."
	cd $INSTALL_PATH
	git clone https://github.com/moodlehq/moodle-local_moodlecheck local/moodlecheck
fi

# Check the specified code.

$PHP $INSTALL_PLUGIN_PATH/cli/moodlecheck.php --path=$CHECK_PATH > $LOG_PATH
echo "Results written to: $LOG_PATH"
