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

# Fill in the settings below, or supply a file with the parameter --prefs /path/to/prefs

# User Home Directory
USERHOME="$HOME"
# AutoPkg Preferences file
AUTOPKG_PREFS="$USERHOME/Library/Preferences/com.github.autopkg.plist"
# AutoPkg Repos List - you can supply a text file. Otherwise just the
# core recipe repo will be added.
AUTOPKG_REPOS="./AutoPkg-Repos.txt"

## JSS address, API user and password
# Comment out JSS_URL if you don't wish to install JSSimporter
JSS_URL="https://changeme.com:8443/"
JSS_API_AUTOPKG_USER="AutoPkg"
JSS_API_AUTOPKG_PW="ChangeMe!!!"

## JSS_TYPE. Set to "SMB", "AFP", "Local", or one of JDS, CDP, AWS or JCDS.
# All cloud methods should be considered experimental.
# Comment out if not configuring JSSImporter
JSS_TYPE="Local"

## Local distribution point?
# Uncomment these:
# JAMFREPO_NAME="CasperShare"
# JAMFREPO_MOUNTPOINT="/Volumes/CasperDistShare"

## FileShare Distribution Server?
# Uncomment these. In normal usage, this is sufficient
# due to information gathered from the JSS.
# JAMFREPO_NAME="CasperShare"
# JAMFREPO_PW="ChangeMeToo!!!"

# Second distribution point? Add the details here as above
# JSS_SECOND_TYPE="Local"
# JAMFREPO_SECOND_MOUNTPOINT="/Volumes/CasperDistShare"
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
    osx_vers=$(sw_vers -productVersion | awk -F "." '{print $2}')
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
    if [[ $use_betas == "yes" ]]; then
        AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["assets"][0]["browser_download_url"]')
    else
        AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases/latest | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["assets"][0]["browser_download_url"]')
    fi
    /usr/bin/curl -L "${AUTOPKG_LATEST}" -o "$1/autopkg-latest.pkg"

    sudo installer -pkg "$1/autopkg-latest.pkg" -target /

    autopkg_version=$(${AUTOPKG} version)

    ${LOGGER} "AutoPkg $autopkg_version Installed"
    echo
    echo "### AutoPkg $autopkg_version Installed"
    echo

    # Clean Up When Done
    rm "$1/autopkg-latest.pkg"
}


secureAutoPkg() {
    touch $AUTOPKG_PREFS
    ${DEFAULTS} write $AUTOPKG_PREFS FAIL_RECIPES_WITHOUT_TRUST_INFO -bool True
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
    if [[ $use_betas == "yes" ]]; then
        ${AUTOPKG} make-override --force JSSImporterBeta.install
    else
        ${AUTOPKG} make-override --force com.github.rtrouton.install.JSSImporter
    fi

    sleep 1
    ${AUTOPKG} run -v JSSImporterBeta.install
}


configureCommon() {
    ${DEFAULTS} write $AUTOPKG_PREFS JSS_URL "${JSS_URL}"
    ${DEFAULTS} write $AUTOPKG_PREFS API_USERNAME ${JSS_API_AUTOPKG_USER}
    ${DEFAULTS} write $AUTOPKG_PREFS API_PASSWORD ${JSS_API_AUTOPKG_PW}
}


configureJSSImporter() {
    # JSSImporter requires the Repo type for cloud instances
    ${PLISTBUDDY} -c "Delete :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS array" ${AUTOPKG_PREFS}
    ${PLISTBUDDY} -c "Add :JSS_REPOS:0 dict" ${AUTOPKG_PREFS}
    [[ $JSS_TYPE != "SMB" && $JSS_TYPE != "AFP" ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:0:type string ${JSS_TYPE}" ${AUTOPKG_PREFS}
    [[ $JAMFREPO_NAME ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:0:name string ${JAMFREPO_NAME}" ${AUTOPKG_PREFS}
    [[ $JAMFREPO_PW ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:0:password string ${JAMFREPO_PW}" ${AUTOPKG_PREFS}
    [[ $JAMFREPO_MOUNTPOINT ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:0:mount_point string ${JAMFREPO_MOUNTPOINT}" ${AUTOPKG_PREFS}
    if [[ $JSS_SECOND_TYPE ]]; then
        ${PLISTBUDDY} -c "Add :JSS_REPOS:1 dict" ${AUTOPKG_PREFS}
        [[ $JSS_SECOND_TYPE != "SMB" && $JSS_SECOND_TYPE != "AFP" ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:1:type string ${JSS_SECOND_TYPE}" ${AUTOPKG_PREFS}
        [[ $JAMFREPO_SECOND_NAME ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:1:name string ${JAMFREPO_SECOND_NAME}" ${AUTOPKG_PREFS}
        [[ $JAMFREPO_SECOND_PW ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:1:password string ${JAMFREPO_SECOND_PW}" ${AUTOPKG_PREFS}
    fi
}

## Main section

# Commands
GIT="/usr/bin/git"
DEFAULTS="/usr/bin/defaults"
AUTOPKG="/usr/local/bin/autopkg"
PLISTBUDDY="/usr/libexec/PlistBuddy"

# logger
LOGGER="/usr/bin/logger -t AutoPkg_Setup"

while test $# -gt 0
do
    case "$1" in
        -f|--force) force_autopkg_update="yes"
        ;;
        -b|--betas)
            force_autopkg_update="yes"
            use_betas="yes"
        ;;
        -s|--sharepoint) install_sharepoint="yes"
        ;;
        -p|--prefs-only|--prefs_only) prefs_only="yes"
        ;;
        --prefs*)
            prefs_file=$(echo $1 | sed -e 's|^[^=]*=||g')
        ;;
        --repo-list*)
            AUTOPKG_REPO_OVERRIDE=$(echo $1 | sed -e 's|^[^=]*=||g')
        ;;
        -h|--help)
            echo "
Usage:
./autopkg_setup_for_jss.sh [--help] [--prefs_only] [--prefs=*] 
                           [--sharepoint] [--force]
                           [--repo-list=*]

-h | --help         Displays this text
-p | --prefs-only   Do not update any repos. Without this option, 
                    'autopkg repo-update all' is run
-f | --force        Force the re-installation of the latest AutoPkg 
-s | --sharepoint   Installs the python modules required to integrate with 
                    SharePoint API
--prefs=*           Path to the preferences file
--repo-list=*       Path to the a repo list. Will add all the repos and 
                    ensure they are updated.

"
            exit 0
        ;;
        *)
            echo "ERROR: invalid parameter provided."
            exit 1
        ;;
    esac
    shift
done

# override settings with a config file
if [[ -f "$prefs_file" ]]; then
    . "$prefs_file"
fi

if [[ -f "$AUTOPKG_REPO_OVERRIDE" ]]; then
    AUTOPKG_REPOS="$AUTOPKG_REPO_OVERRIDE"
fi

# skip autopkg updates if set to just update prefs
if [[ $prefs_only != "yes" ]]; then
    # Check for Command line tools.
    xcode-select -p >/dev/null 2>&1
    if [[ $? > 0 ]]; then
        installCommandLineTools
    fi

    # Get AutoPkg if not already installed
    if [[ ! -f "${AUTOPKG}" || $force_autopkg_update == "yes" ]]; then
        installAutoPkg "${USERHOME}"
        ${LOGGER} "AutoPkg installed and secured"
        echo
        echo "### AutoPkg installed and secured"
    fi

    # ensure untrusted recipes fail
    secureAutoPkg

    ## AutoPkg repos:
    # homebysix-recipes required for standard JSSImporter.install.
    # grahampugh-recipes required for beta JSSImporterBeta.install.
    # jss-recipes required for easy access to icons and descriptions.
    # Add more recipe repos here if required.
    if [[ -f "$AUTOPKG_REPOS" ]]; then
        read -r -d '' AUTOPKGREPOS < "$AUTOPKG_REPOS"
    else
        read -r -d '' AUTOPKGREPOS <<ENDMSG
recipes
rtrouton-recipes
jss-recipes
grahampugh-recipes
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

    if [[ $install_sharepoint == "yes" ]]; then
        # We need some python modules for the Sharepointer stuff to work
        # Try this:
        /usr/local/autopkg/python -m ensurepip --user
        /usr/local/autopkg/python -m pip install --upgrade pip --user
        /usr/local/autopkg/python -m pip install lxml cryptography --user
        /usr/local/autopkg/python -m pip install --index-url https://test.pypi.org/simple/ --no-deps python-ntlm3-eth-its sharepoint-eth-its --ignore-installed --user
        if [[ $? = 0 ]]; then
            ${LOGGER} "Python requirements installed"
            echo
            echo "### Python requirements installed"
        else
            ${LOGGER} "Python requirements not properly installed"
            echo
            echo "### Python requirements not properly installed"
        fi
    fi

    # Install JSSImporter using AutoPkg install recipe
    [[ $JSS_TYPE ]] && installJSSImporter
fi


# configure repos in com.github.autopkg
if [[ $JSS_TYPE ]]; then
    configureCommon
    configureJSSImporter
    ${LOGGER} "AutoPkg JSSImporter Configured for $JSS_TYPE Distribution Point."
    echo
    echo "### AutoPkg JSSImporter Configured for $JSS_TYPE Distribution Point"

    if [[ $JSS_SECOND_TYPE ]]; then
        ${LOGGER} "AutoPkg JSSImporter Configured for $JSS_SECOND_TYPE Distribution Point."
        echo
        echo "### AutoPkg JSSImporter Configured for $JSS_SECOND_TYPE Distribution Point"
    fi
else
    ${LOGGER} "JSSImporter not configured. Skipping."
    echo
    echo "### JSSImporter not configured. Skipping."
fi
