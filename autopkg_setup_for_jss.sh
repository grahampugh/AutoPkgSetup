#!/bin/bash

# AutoPkg_Setup_for_JSS (bash version)
# by Graham Pugh

# AutoPkg_Setup_for_JSS automates the installation of the latest version
# of AutoPkg and prerequisites for using JSSImporter

# Acknowledgements
# Excerpts from https://github.com/grahampugh/run-munki-run
# which in turn borrows from https://github.com/tbridge/munki-in-a-box
# JSSImporter processor and settings:  https://github.com/jssimporter/JSSImporter

# -------------------------------------------------------------------------------------- #
## Editable locations and settings

# Fill in the settinbgs below, or supply a file with the same settings as
# Parameter 1 ($1)

# User Home Directory
USERHOME="$HOME"
# AutoPkg Preferences file
AUTOPKG_PREFS="$USERHOME/Library/Preferences/com.github.autopkg.plist"
PYTHONJSS_PREFS="$USERHOME/Library/Preferences/com.github.sheagcraig.python-jss.plist"
# AutoPkg Repos List - you can supply a text file. Otherwise just the
# core recipe repo will be added.
AUTOPKG_REPOS="./AutoPkg-Repos.txt"

## JSS address, API user and password
# Comment out JSS_URL if you don't wish to install JSSimporter
JSS_URL="https://changeme.com:8443/"
JSS_API_AUTOPKG_USER="AutoPkg"
JSS_API_AUTOPKG_PW="ChangeMe!!!"

## JSS_TYPE. Set to "DP", "Local", or one of JDS, CDP, AWS or JCDS.
# All cloud methods should be considered experimental.
# Set to "None" or comment out if not configuring JSSImporter or using
# one or more distribution point
JSS_TYPE="Local"

## Local distribution point?
# Uncomment these:
# JAMFREPO_NAME="CasperShare"
# JAMFREPO_MOUNTPOINT="/Volumes/CasperDistShare"

## Jamf Distribution Server?
# Uncomment these. In normal usage, this is sufficient
# due to information gathered from the JSS.
JAMFREPO_NAME="CasperShare"
JAMFREPO_PW="ChangeMeToo!!!"
# Second JDS? Add the details here
# JAMFREPO_SECOND_NAME="CasperShareToo"
# JAMFREPO_SECOND_PW="ChangeMeToo!!!"

## Private AutoPkg repo
# to add a private repo that cannot be handled automatically by 'repo-add'
# for example an ssh-based repo connection, you need to supply the following:
AUTOPKG_RECIPE_REPOS_FOLDER="$USERHOME/Library/AutoPkg/RecipeRepos"
# AUTOPKG_PRIVATE_REPO_URI="git@gitlab.example.com:owner/autopkg-recipe-repo.git"
# AUTOPKG_PRIVATE_REPO_ID="com.example.gitlab.owner.autopkg-recipe-repo"

# -------------------------------------------------------------------------------------- #
## No editing required below here


rootCheck() {
    # Check that the script is NOT running as root
    if [[ $EUID -eq 0 ]]; then
        echo "### This script is NOT MEANT to run as root."
        echo "This script is meant to be run as an admin user."
        echo "Please run without sudo."
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
    touch $AUTOPKG_PREFS
    ${DEFAULTS} write $AUTOPKG_PREFS -bool YES
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
    ${AUTOPKG} make-override JSSImporterBeta.install
    sleep 1
    ${AUTOPKG} run -v JSSImporterBeta.install

    ## Very latest with STOP_IF_NO_JSS_UPLOAD key needs to be downloaded
    #echo
    #echo "### Downloading very latest JSSImporter.py"
    #JSSIMPORTER_LATEST="https://raw.githubusercontent.com/grahampugh/JSSImporter/testing/JSSImporter.py"
    #sudo /usr/bin/curl -L "${JSSIMPORTER_LATEST}" -o "/Library/AutoPkg/autopkglib/JSSImporter.py"
    # ^- No longer need to download beta2 now that JSS Importer 1.0.2b3 is available in Master
}


configureCommon() {
    ${DEFAULTS} write $AUTOPKG_PREFS JSS_URL "${JSS_URL}"
    ${DEFAULTS} write $AUTOPKG_PREFS API_USERNAME ${JSS_API_AUTOPKG_USER}
    ${DEFAULTS} write $AUTOPKG_PREFS API_PASSWORD ${JSS_API_AUTOPKG_PW}
}

configureJSSImporterWithDistributionPoints() {
    # JSSImporter requires the Repo type for cloud instances
    ${PLISTBUDDY} -c "Delete :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0 dict" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:name string ${JAMFREPO_NAME}" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:password string ${JAMFREPO_PW}" ${AUTOPKG_PREFS}
    if [[ $JAMFREPO_SECOND_NAME ]]; then
        ${PLISTBUDDY} -c "Add :JSS_REPOS:1 dict" ${AUTOPKG_PREFS}
        ${PLISTBUDDY} -c "Add :JSS_REPOS:1:name string ${JAMFREPO_SECOND_NAME}" ${AUTOPKG_PREFS}
        ${PLISTBUDDY} -c "Add :JSS_REPOS:1:password string ${JAMFREPO_SECOND_PW}" ${AUTOPKG_PREFS}
    fi
}


configureJSSImporterWithCloudRepo() {
    # JSSImporter requires the Repo type for cloud instances
    ${PLISTBUDDY} -c "Delete :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0 dict" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:type string ${JSS_TYPE}" ${AUTOPKG_PREFS}
}


configureJSSImporterWithLocalRepo() {
    # JSSImporter requires the Repo type for cloud instances
    ${PLISTBUDDY} -c "Delete :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0 dict" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:type string Local" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:mount_point string ${JAMFREPO_MOUNTPOINT}" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:share_name string ${JAMFREPO_NAME}" ${AUTOPKG_PREFS}
}


configurePythonJSS() {
    ${DEFAULTS} write "${PYTHONJSS_PREFS}" jss_url "${JSS_URL}"
    ${DEFAULTS} write "${PYTHONJSS_PREFS}" jss_user ${JSS_API_AUTOPKG_USER}
    ${DEFAULTS} write "${PYTHONJSS_PREFS}" jss_pass ${JSS_API_AUTOPKG_PW}
}


## Main section

# Commands
GIT="/usr/bin/git"
DEFAULTS="/usr/bin/defaults"
AUTOPKG="/usr/local/bin/autopkg"
PLISTBUDDY="/usr/libexec/PlistBuddy"

# logger
LOGGER="/usr/bin/logger -t AutoPkg_Setup"

# override settings with a config file
if [[ -f "$1" ]]; then
    . "$1"
fi

# Check for Command line tools.
xcode-select -p >/dev/null 2>&1
if [[ $? > 0 ]]; then
    installCommandLineTools
fi

# Get AutoPkg if not already installed
if [[ ! -f "${AUTOPKG}" || $2 == "force" ]]; then
    installAutoPkg "${USERHOME}"
    # ensure untrusted recipes fail
    secureAutoPkg
    ${LOGGER} "AutoPkg installed and secured"
    echo
    echo "### AutoPkg installed and secured"
fi

## AutoPkg repos:
# homebysix-recipes required for standard JSSImporter.install.
# grahampugh/recipes required for beta JSSImporterBeta.install.
# jss-recipes required for easy access to icons and descriptions.
# Our local recipes required for importing from Jenkins Builds.
# Add more recipe repos here if required.
if [[ -f "$AUTOPKG_REPOS" ]]; then
    read -r -d '' AUTOPKGREPOS < "$AUTOPKG_REPOS"
else
    read -r -d '' AUTOPKGREPOS <<ENDMSG
recipes
grahampugh/recipes
ENDMSG
fi

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
    ${LOGGER} "Private AutoPkg Repo Configured"
    echo
    echo "### Private AutoPkg Repo Configured"
fi


# We need some python modules for the Sharepointer sand JSSImporter stuff to work
# Try this:
python -m ensurepip --user
python -m pip install --upgrade pip --user
python -m pip install requests lxml sharepoint python-ntlm cryptography --user
if [[ $? = 0 ]]; then
    ${LOGGER} "Python requirements installed"
    echo
    echo "### Python requirements installed"
else
    ${LOGGER} "Python requirements not properly installed"
    echo
    echo "### Python requirements not properly installed"
fi


# Install JSSImporter using AutoPkg install recipe
# NOTE! At the moment this uses the beta.
# (requires grahampugh-recipes)
if [[ $JSS_TYPE == "DP" ]]; then
    installJSSImporter
    configureCommon
    configurePythonJSS
    configureJSSImporterWithDistributionPoints
    ${LOGGER} "AutoPkg JSSImporter Configured for Distribution Point(s)"
    echo
    echo "### AutoPkg JSSImporter Configured for Distribution Point(s)"
elif [[ $JSS_TYPE == "Local" ]]; then
    installJSSImporter
    configureCommon
    configurePythonJSS
    configureJSSImporterWithLocalRepo
    ${LOGGER} "AutoPkg JSSImporter Configured for Local Distribution Point"
    echo
    echo "### AutoPkg JSSImporter Configured for Local Distribution Point"
elif [[ $JSS_TYPE == "JCDS" || $JSS_TYPE == "JDS" || $JSS_TYPE == "AWS" || $JSS_TYPE == "CDP" ]]; then
    installJSSImporter
    configureCommon
    configurePythonJSS
    configureJSSImporterWithCloudRepo
    ${LOGGER} "AutoPkg JSSImporter Configured for Cloud Distribution Point"
    echo
    echo "### AutoPkg JSSImporter Configured for Cloud Distribution Point"
else
    ${LOGGER} "JSSImporter not configured. Skipping."
    echo
    echo "### JSSImporter not configured. Skipping."
fi
