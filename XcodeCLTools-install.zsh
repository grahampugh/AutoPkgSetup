#!/bin/zsh
# shellcheck shell=bash

: <<DOC
Installing the Xcode command line tools on Darwin 15 or higher
Adapted from
https://github.com/rtrouton/rtrouton_scripts/tree/master/rtrouton_scripts/install_xcode_command_line_tools
DOC

cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

# convert a macOS major version to a darwin version
os_version=$(sw_vers -productVersion)
if [[ "${os_version:0:2}" == "10" ]]; then
    darwin_version=${os_version:3:2}
    darwin_version=$((darwin_version+4))
else
    darwin_version=${os_version:0:2}
    darwin_version=$((darwin_version+9))
fi

# installing the latest Xcode command line tools

if [[ "$darwin_version" -lt 15 ]] ; then
    echo "macOS version $os_version is too old for this script"
    exit 1
fi

echo "macOS version $os_version - proceeding"

# create the placeholder file which is checked by the softwareupdate tool
# before allowing the installation of the Xcode command line tools.

touch "$cmd_line_tools_temp_file"

# identify the correct update in the Software Update feed with "Command Line Tools" in the name
if [[ "$darwin_version" -ge 19 ]] ; then
    cmd_line_tools=$(softwareupdate -l | awk '/\*\ Label: Command Line Tools/ { $1=$1;print }' | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 9- | head -n 1)
else
    cmd_line_tools=$(softwareupdate -l | awk '/\*\ Command Line Tools/ { $1=$1;print }' | grep "${os_version:3:2}" | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)
fi

# Iistall the command line tools
if [[ ${cmd_line_tools} ]]; then
    echo "Download found - installing"
    softwareupdate -i "$cmd_line_tools" --verbose
else
    echo "Download not found"
fi

# remove the temp file
if [[ -f "$cmd_line_tools_temp_file" ]]; then
    rm "$cmd_line_tools_temp_file"
fi
