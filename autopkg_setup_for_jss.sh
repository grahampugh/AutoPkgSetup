#!/bin/bash

# AutoPkg_Setup_for_JSS (bash version)
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

# JSS_TYPE. Set to "Local", "Cloud". Cloud means either JDS or JCDS
# Set to "None" if not configuring JSSImporter
JSS_TYPE="Local"


# JSS address, API user and password
# Comment out JSS_URL if you don't wish to install AutoPkg
JSS_URL="https://changeme.com:8443/"
JSS_API_AUTOPKG_USER="AutoPkg"
JSS_API_AUTOPKG_PW="ChangeMe!!!"

# Jamf Distribution Server name and password. In normal usage, this is sufficient
# due to information gathered from the JSS.
JAMFREPO_NAME="CasperShare"
JAMFREPO_PW="ChangeMeToo!!!"

## AutoPkg repos:
# homebysix-recipes required for JSSImporter.install.
# jss-recipes required for easy access to icons and descriptions.
# Our local recipes required for importing from Jenkins Builds.
# Add more recipe repos here if required.
read -r -d '' AUTOPKGREPOS <<ENDMSG
recipes
grahampugh/recipes
ENDMSG


# Private AutoPkg repo
# AUTOPKG_RECIPE_REPOS_FOLDER="$USERHOME/Library/AutoPkg/RecipeRepos"
# AUTOPKG_PRIVATE_REPO_URI="git@gitlab.ethz.ch:id-cd-mac/id-mac-autopkg-recipes.git"
# AUTOPKG_PRIVATE_REPO_ID="ch.ethz.gitlab.id-cd-mac.id-mac-autopkg-recipes"


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

    # Clean Up When Done
    rm "$1/autopkg-latest.pkg"
}


secureAutoPkg() {
    ${DEFAULTS} write com.github.autopkg FAIL_RECIPES_WITHOUT_TRUST_INFO -bool YES
}


setupPrivateRepo() {
    # AutoPkg has no built-in commands for adding private repos as SSH so that you can use a key
    # This does the work. Thanks to https://www.johnkitzmiller.com/blog/using-a-private-repository-with-autopkgautopkgr/

    # clone the reciperepo if it isn't there already
    if [[ ! -d "$AUTOPKG_RECIPE_REPOS_FOLDER/$AUTOPKG_PRIVATE_REPO_ID" ]]; then
        ${GIT} clone $AUTOPKG_PRIVATE_REPO_URI "$AUTOPKG_RECIPE_REPOS_FOLDER/$AUTOPKG_PRIVATE_REPO_ID"
    fi

    # add to AutoPkg prefs RECIPE_REPOS
    # First check if it's already there - we can leave it alone if so!
    if ! ${PLISTBUDDY} -c "Print :RECIPE_REPOS:$AUTOPKG_RECIPE_REPOS_FOLDER/$AUTOPKG_PRIVATE_REPO_ID" ${AUTOPKG_PREFS} &>/dev/null; then
        ${PLISTBUDDY} -c "Add :RECIPE_REPOS:$AUTOPKG_RECIPE_REPOS_FOLDER/$AUTOPKG_PRIVATE_REPO_ID dict" ${AUTOPKG_PREFS}
        ${PLISTBUDDY} -c "Add :RECIPE_REPOS:$AUTOPKG_RECIPE_REPOS_FOLDER/$AUTOPKG_PRIVATE_REPO_ID:URL string $AUTOPKG_PRIVATE_REPO_URI" ${AUTOPKG_PREFS}
    fi

    # add to AutoPkg prefs RECIPE_SEARCH_DIRS
    # First check if it's already there - we can leave it alone if so!
    privateRecipeID=$(${PLISTBUDDY} -c "Print :RECIPE_SEARCH_DIRS" ${AUTOPKG_PREFS} | grep "$AUTOPKG_RECIPE_REPOS_FOLDER/$AUTOPKG_PRIVATE_REPO_ID")
    if [ -z "$privateRecipeID" ]; then
        ${PLISTBUDDY} -c "Add :RECIPE_SEARCH_DIRS: string '$AUTOPKG_RECIPE_REPOS_FOLDER/$AUTOPKG_PRIVATE_REPO_ID'" ${AUTOPKG_PREFS}
    fi
}


installJSSImporter() {
    # Install JSSImporter using AutoPkg install recipe
    echo
    echo "### Downloading JSSImporter pkg from AutoPkg"
    ${AUTOPKG} make-override JSSImporterBeta.install.recipe
    ${AUTOPKG} run JSSImporterBeta.install.recipe

    # Very latest with STOP_IF_NO_JSS_UPLOAD key needs to be downloaded
    JSSIMPORTER_LATEST="https://raw.githubusercontent.com/grahampugh/JSSImporter/testing/JSSImporter.py"
    echo
    echo "### Downloading very latest JSSImporter.py"
    sudo /usr/bin/curl -L "${JSSIMPORTER_LATEST}" -o "/Library/AutoPkg/autopkglib/JSSImporter.py"
}


configureJSSImporterWithLocalRepo() {
    # JSSImporter requires the Repo type for cloud instances
    ${DEFAULTS} write com.github.autopkg JSS_URL "${JSS_URL}"
    ${DEFAULTS} write com.github.autopkg API_USERNAME ${JSS_API_AUTOPKG_USER}
    ${DEFAULTS} write com.github.autopkg API_PASSWORD ${JSS_API_AUTOPKG_PW}
    ${DEFAULTS} write com.github.autopkg JSS_MIGRATED True
    ${PLISTBUDDY} -c "Delete :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0 dict" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:name string ${JAMFREPO_NAME}" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:password string ${JAMFREPO_PW}" ${AUTOPKG_PREFS}
}


configureJSSImporterWithCloudRepo() {
    # JSSImporter requires the Repo type for cloud instances
    ${DEFAULTS} write com.github.autopkg JSS_URL "${JSS_URL}"
    ${DEFAULTS} write com.github.autopkg API_USERNAME ${JSS_API_AUTOPKG_USER}
    ${DEFAULTS} write com.github.autopkg API_PASSWORD ${JSS_API_AUTOPKG_PW}
    ${DEFAULTS} write com.github.autopkg JSS_MIGRATED True
    ${PLISTBUDDY} -c "Delete :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0 dict" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:type string JDS" ${AUTOPKG_PREFS}
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

# ensure untrusted recipes fail
secureAutoPkg

${LOGGER} "AutoPkg installed and secured"
echo
echo "### AutoPkg installed and secured"

# Add AutoPkg repos (checks if already added)
${AUTOPKG} repo-add ${AUTOPKGREPOS}

# Update AutoPkg repos (if the repos were already there no update would otherwise happen)
${AUTOPKG} repo-update all

${LOGGER} "AutoPkg Repos Configured"
echo
echo "### AutoPkg Repos Configured"


# Add private repo if set
if [[ $AUTOPKG_PRIVATE_REPO_URI ]]; then
    setupPrivateRepo
fi


# We need some python modules for the Sharepointer sand JSSImporter tuff to work
# Try this:
python -m ensurepip --user
python -m pip install --upgrade pip --user
python -m pip install requests lxml sharepoint python-ntlm cryptography --user


# Install JSSImporter using AutoPkg install recipe
# NOTE! At the moment this uses the beta.
# (requires grahampugh-recipes)
if [[ $JSS_TYPE == "Local" ]]; then
    installJSSImporter
    configureJSSImporterWithLocalRepo
    ${LOGGER} "AutoPkg JSSImporter Configured"
    echo
    echo "### AutoPkg JSSImporter Configured"
elif [[ $JSS_TYPE == "Cloud" ]]; then
    installJSSImporter
    configureJSSImporterWithCloudRepo
    ${LOGGER} "AutoPkg JSSImporter Configured"
    echo
    echo "### AutoPkg JSSImporter Configured"
else
    ${LOGGER} "JSSImporter not configured. Skipping."
    echo
    echo "### JSSImporter not configured. Skipping."
fi
