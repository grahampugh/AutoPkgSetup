#!/bin/bash

# AutoPkg_Setup_for_JSS
# by Graham Pugh

# AutoPkg_Setup_for_JSS automates the installation of the latest version of AutoPkg and prerequisites for using JSS_Importer

# Acknowledgements
# Excerpts from https://github.com/grahampugh/run-munki-run
# which in turn borrows from https://github.com/tbridge/munki-in-a-box
# JSSImporter processor and settings from https://github.com/sheagcraig/JSSImporter
# AutoPkg SubDirectoryList processor from https://github.com/facebook/Recipes-for-AutoPkg

# -------------------------------------------------------------------------------------- #
## Editable locations and settings

# User Home Directory
USERHOME="$HOME"
# AutoPkg Preferences file
AUTOPKG_PREFS="$USERHOME/Library/Preferences/com.github.autopkg.plist"

# JSS address, API user and password
# JSS_URL="https://changeme.com:8443/"
# JSS_API_AUTOPKG_USER="AutoPkg"
# JSS_API_AUTOPKG_PW="ChangeMe!!!"

# Jamf Distribution Server name and password. In normal usage, this is sufficient
# due to information gathered from the JSS.
# JAMFREPO_NAME="CasperShare"
# JAMFREPO_PW="ChangeMeToo!!!"

## AutoPkg repos:
# homebysix-recipes required for JSSImporter.install.
# jss-recipes required for easy access to icons and descriptions.
# Our local recipes required for importing from Jenkins Builds.
# Add more recipe repos here if required.
read -r -d '' AUTOPKGREPOS <<ENDMSG
recipes
ENDMSG


# -------------------------------------------------------------------------------------- #
## No editing required below here

rootCheck() {
    # Check that the script is NOT running as root
    if [[ $EUID -eq 0 ]]; then
        echo "### This script is NOT MEANT to run as root. This script is meant to be run as an admin user. I'm going to quit now. Run me without the sudo, please."
        echo
        exit 4 # Running as root.
    fi
}

installCommandLineTools() {
    # Installing the Xcode command line tools on 10.10+
    # This section written by Rich Trouton.
    echo "### Installing the command line tools..."
    echo
    cmd_line_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"

    # Installing the latest Xcode command line tools on 10.9.x or 10.10.x

    if [[ "$osx_vers" -ge 9 ]] ; then

        # Create the placeholder file which is checked by the softwareupdate tool
        # before allowing the installation of the Xcode command line tools.
        touch "$cmd_line_tools_temp_file"

        # Find the last listed update in the Software Update feed with "Command Line Tools" in the name
        cmd_line_tools=$(softwareupdate -l | awk '/\*\ Command Line Tools/ { $1=$1;print }' | tail -1 | sed 's/^[[ \t]]*//;s/[[ \t]]*$//;s/*//' | cut -c 2-)

        #Install the command line tools
        sudo softwareupdate -i "$cmd_line_tools" -v

        # Remove the temp file
        if [[ -f "$cmd_line_tools_temp_file" ]]; then
            rm "$cmd_line_tools_temp_file"
        fi
    else
        echo "Sorry, this script is only for use on OS X/macOS >= 10.9"
    fi
}

installAutoPkg() {
    # Get AutoPkg
    # thanks to Nate Felton
    # Inputs: 1. $USERHOME
    AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["assets"][0]["browser_download_url"]')
    /usr/bin/curl -L "${AUTOPKG_LATEST}" -o "$1/autopkg-latest.pkg"

    sudo installer -pkg "$1/autopkg-latest.pkg" -target /

    ${LOGGER} "AutoPkg Installed"
    echo
    echo "### AutoPkg Installed"
    echo
}

## Main section

# Commands
GIT="/usr/bin/git"
DEFAULTS="/usr/bin/defaults"
AUTOPKG="/usr/local/bin/autopkg"
PLISTBUDDY="/usr/libexec/PlistBuddy"

# logger
LOGGER="/usr/bin/logger -t AutoPkg_Setup"


# Check for Command line tools.
if [[ ! -f "/usr/bin/git" ]]; then
    installCommandLineTools
fi

# Get AutoPkg if not already installed
if [[ ! -d ${AUTOPKG} ]]; then
    installAutoPkg "${USERHOME}"
fi

${LOGGER} "AutoPkg Installed"
echo
echo "### AutoPkg Installed"

# Add AutoPkg repos (checks if already added)
${AUTOPKG} repo-add ${AUTOPKGREPOS}

# Update AutoPkg repos (if the repos were already there no update would otherwise happen)
${AUTOPKG} repo-update ${AUTOPKGREPOS}

${LOGGER} "AutoPkg Repos Configured"
echo
echo "### AutoPkg Repos Configured"

# Install JSSImporter using AutoPkg install recipe
# (requires homebysix-recipes)
# ${AUTOPKG} make-override JSSImporter.install.recipe
# ${AUTOPKG} run JSSImporter.install.recipe


# Clean Up When Done
rm "$USERHOME/autopkg-latest.pkg"
