#!/bin/bash

# AutoPkg_Setup_for_JSSImporter
# by Graham Pugh

# AutoPkg_Setup_for_JSSImporter automates the installation of the latest version
# of AutoPkg and prerequisites for using JSSImporter

# Acknowledgements
# Excerpts from https://github.com/grahampugh/run-munki-run
# which in turn borrows from https://github.com/tbridge/munki-in-a-box
# JSSImporter processor and settings:  https://github.com/jssimporter/JSSImporter

# -------------------------------------------------------------------------------------- #
# designed to be used with prefs files that autopkg can run with the --prefs option
# These are easy to make with defaults commands or using YAML. 
# Store them in a private git account.
# This script will ensure that all repos are added to the server.
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
    ${DEFAULTS} write "$AUTOPKG_PREFS" FAIL_RECIPES_WITHOUT_TRUST_INFO -bool true
}


setupPrivateRepo() {
    # AutoPkg has no built-in commands for adding private repos as SSH so that you can use a key
    # This does the work. Thanks to https://www.johnkitzmiller.com/blog/using-a-private-repository-with-autopkgautopkgr/

    # clone the recipe repo if it isn't there already
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
    echo "### Downloading JSSImporter pkg from AutoPkg"
    if [[ $use_betas == "yes" ]]; then
        ${AUTOPKG} repo-add grahampugh-recipes
        ${AUTOPKG} make-override --force JSSImporterBeta.install
    else
        ${AUTOPKG} repo-add grahampugh-recipes
        ${AUTOPKG} make-override --force com.github.rtrouton.install.JSSImporter
    fi

    sleep 1
    ${AUTOPKG} run -v JSSImporterBeta.install
    echo
}


configureJSSImporter() {
    # get URL
    if [[ "${JSS_URL}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" JSS_URL "${JSS_URL}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" JSS_URL ; then
        printf '%s ' "JSS_URL required. Please enter : "
        read JSS_URL
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" JSS_URL "${JSS_URL}"
    fi

    # get API user
    if [[ "${JSS_API_USER}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_USERNAME "${JSS_URL}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" API_USERNAME ; then
        printf '%s ' "API_USERNAME required. Please enter : "
        read JSS_API_USER
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_USERNAME "${JSS_URL}"
    fi

    # get API user's password
    if [[ "${JSS_API_PW}" == "-" ]]; then
        printf '%s ' "API_PASSWORD for ${JSS_API_USER} required. Please enter : "
        read -s JSS_API_PW
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_PASSWORD "${JSS_API_PW}"
    elif [[ "${JSS_API_PW}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_PASSWORD "${JSS_API_PW}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" API_PASSWORD ; then
        printf '%s ' "API_PASSWORD for ${JSS_API_USER} required. Please enter : "
        read -s JSS_API_PW
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_PASSWORD "${JSS_API_PW}"
    fi

    # JSSImporter requires the Repo type for cloud instances
    if [[ "$JSS_TYPE" ]]; then
        ${PLISTBUDDY} -c "Delete :JSS_REPOS array" "${AUTOPKG_PREFS}"
        ${PLISTBUDDY} -c "Add :JSS_REPOS array" "${AUTOPKG_PREFS}"
        ${PLISTBUDDY} -c "Add :JSS_REPOS:0 dict" "${AUTOPKG_PREFS}"
        [[ $JSS_TYPE != "SMB" && $JSS_TYPE != "AFP" ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:0:type string ${JSS_TYPE}" "${AUTOPKG_PREFS}"
        [[ $JAMFREPO_NAME ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:0:name string ${JAMFREPO_NAME}" "${AUTOPKG_PREFS}"
        [[ $JAMFREPO_PW ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:0:password string ${JAMFREPO_PW}" "${AUTOPKG_PREFS}"
        [[ $JAMFREPO_MOUNTPOINT ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:0:mount_point string ${JAMFREPO_MOUNTPOINT}" "${AUTOPKG_PREFS}"

        if [[ $JSS_SECOND_TYPE ]]; then
            ${PLISTBUDDY} -c "Add :JSS_REPOS:1 dict" "${AUTOPKG_PREFS}"
            [[ $JSS_SECOND_TYPE != "SMB" && $JSS_SECOND_TYPE != "AFP" ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:1:type string ${JSS_SECOND_TYPE}" "${AUTOPKG_PREFS}"
            [[ $JAMFREPO_SECOND_NAME ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:1:name string ${JAMFREPO_SECOND_NAME}" "${AUTOPKG_PREFS}"
            [[ $JAMFREPO_SECOND_PW ]] && ${PLISTBUDDY} -c "Add :JSS_REPOS:1:password string ${JAMFREPO_SECOND_PW}" "${AUTOPKG_PREFS}"
        fi
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" JSS_REPOS ; then
        printf '%s ' "JSS_REPOS required. Please enter JSS_TYPE : "
        read JSS_TYPE
        echo
        ${PLISTBUDDY} -c "Add :JSS_REPOS array" "${AUTOPKG_PREFS}"
        ${PLISTBUDDY} -c "Add :JSS_REPOS:0 dict" "${AUTOPKG_PREFS}"
        if [[ $JSS_TYPE != "SMB" && $JSS_TYPE != "AFP" ]]; then 
            ${PLISTBUDDY} -c "Add :JSS_REPOS:0:type string ${JSS_TYPE}" "${AUTOPKG_PREFS}"
        else
            if [[ ! $JAMFREPO_NAME ]]; then 
                printf '%s ' "JAMFREPO_NAME required. Please enter : "
                read JAMFREPO_NAME
                echo
            fi
            ${PLISTBUDDY} -c "Add :JSS_REPOS:0:name string ${JAMFREPO_NAME}" "${AUTOPKG_PREFS}"

            if [[ ! $JAMFREPO_PW ]]; then 
                printf '%s ' "JAMFREPO_PW for $JAMFREPO_NAME required. Please enter : "
                read -s JAMFREPO_PW
                echo
            fi
            ${PLISTBUDDY} -c "Add :JSS_REPOS:0:password string ${JAMFREPO_PW}" "${AUTOPKG_PREFS}"

            if [[ ! $JAMFREPO_MOUNTPOINT ]]; then 
                printf '%s ' "JAMFREPO_MOUNTPOINT required. Please enter : "
                read JAMFREPO_MOUNTPOINT
                echo
            fi
            ${PLISTBUDDY} -c "Add :JSS_REPOS:0:mount_point string ${JAMFREPO_MOUNTPOINT}" "${AUTOPKG_PREFS}"
        fi
    fi
    echo
}


installSharepoint() {
    # We need some python modules for the Sharepointer stuff to work
    /usr/local/autopkg/python -m ensurepip --user
    /usr/local/autopkg/python -m pip install --upgrade pip --user
    /usr/local/autopkg/python -m pip install lxml cryptography --user
    /usr/local/autopkg/python -m pip install --index-url https://test.pypi.org/simple/ --no-deps python-ntlm3-eth-its sharepoint-eth-its --ignore-installed --user
    if [[ $? = 0 ]]; then
        ${LOGGER} "Python requirements installed"
        echo "### Python requirements installed"
    else
        ${LOGGER} "Python requirements not properly installed"
        echo "### Python requirements not properly installed"
    fi
    echo
}

configureSharepoint() {
    # get SP API user
    if [[ "${SP_USER}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_USER "${SP_USER}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SP_USER ; then
        printf '%s ' "SP_USER required. Please enter : "
        read SP_USER
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_USER "${SP_USER}"
    fi

    # get SP API user's password
    if [[ "${SP_PASS}" == "-" ]]; then
        printf '%s ' "SP_PASS for ${SP_USER} required. Please enter : "
        read -s SP_PASS
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_PASS "${SP_PASS}"
    elif [[ "${SP_PASS}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_PASS "${SP_PASS}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SP_PASS ; then
        printf '%s ' "SP_PASS for ${SP_USER} required. Please enter : "
        read -s SP_PASS
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_PASS "${SP_PASS}"
    fi
    echo
}

configureSlack() {
    # get Slack user
    if [[ "${SLACK_USER}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SLACK_USER "${SLACK_USER}"
        echo "### Slack user ${SLACK_USER} written to $AUTOPKG_PREFS"
    fi

    # get Slack webhook
    if [[ "${SLACK_WEBHOOK}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SLACK_WEBHOOK "${SLACK_WEBHOOK}"
        echo "### Slack webhook written to $AUTOPKG_PREFS"
    fi
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
        --prefs)
            shift
            AUTOPKG_PREFS="$1"
            [[ $AUTOPKG_PREFS == "/"* ]] || AUTOPKG_PREFS="$(pwd)/${AUTOPKG_PREFS}"
        ;;
        --private_repo)
            shift
            AUTOPKG_PRIVATE_REPO_ID="$1"
        ;;
        --private_repo_url)
            shift
            AUTOPKG_PRIVATE_REPO_URI="$1"
        ;;
        --repo-list)
            shift
            AUTOPKG_REPO_LIST="$1"
        ;;
        --jss-type)
            shift
            JSS_TYPE="$1"
        ;;
        --jss-repo)
            shift
            JAMFREPO_NAME="$1"
        ;;
        --jss-repo-pass)
            shift
            JAMFREPO_PASS="$1"
        ;;
        --jss-repo-mount)
            shift
            JAMFREPO_MOUNTPOINT="$1"
        ;;
        --jss-type-2)
            shift
            JSS_SECOND_TYPE="$1"
        ;;
        --jss-repo-2)
            shift
            JAMFREPO_SECOND_NAME="$1"
        ;;
        --jss-repo-2-pass)
            shift
            JAMFREPO_SECOND_PASS="$1"
        ;;
        --jss-url)
            shift
            JSS_URL="$1"
        ;;
        --jss-user)
            shift
            JSS_API_USER="$1"
        ;;
        --jss-pass)
            shift
            JSS_API_PW="$1"
        ;;
        --slack-webhook)
            shift
            SLACK_WEBHOOK="$1"
        ;;
        --slack-user)
            shift
            SLACK_USER="$1"
        ;;
        --sp-user)
            shift
            SP_USER="$1"
        ;;
        --sp-pass)
            shift
            SP_PASS="$1"
        ;;
        *)
            echo "
Usage:
./autopkg_setup_for_jssimporter.sh [--help] [--prefs_only] [--prefs=*] 
                           [--sharepoint] [--force]
                           [--repo-list=*]

-h | --help         Displays this text
-f | --force        Force the re-installation of the latest AutoPkg 
-s | --sharepoint   Installs the python modules required to integrate with 
                    SharePoint API
-p | --prefs *      Path to the preferences plist
"
            exit 0
        ;;
    esac
    shift
done

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

# read the supplied prefs file or else use the default
if [[ ! $AUTOPKG_PREFS ]]; then
    AUTOPKG_PREFS="/Library/Preferences/com.github.autopkg.plist"
fi

# check that the prefs exist and are valid
if /usr/bin/plutil -lint "$AUTOPKG_PREFS" ; then 
    echo "$AUTOPKG_PREFS is a valid plist"
else
    echo "ERROR: $AUTOPKG_PREFS is not a valid plist!"
    exit 1
fi

# ensure untrusted recipes fail
secureAutoPkg

## AutoPkg repos:
# rtrouton-recipes required for standard JSSImporter.install.
# grahampugh-recipes required for beta JSSImporterBeta.install.
# jss-recipes required for easy access to icons and descriptions.
# Add more recipe repos here if required.
if [[ -f "$AUTOPKG_REPO_LIST" ]]; then
    read -r -d '' AUTOPKGREPOS < "$AUTOPKG_REPO_LIST"
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
if [[ $AUTOPKG_PRIVATE_REPO && $AUTOPKG_PRIVATE_REPO_URI ]]; then
    setupPrivateRepo
    ${LOGGER} "Private AutoPkg Repo Configured"
    echo
    echo "### Private AutoPkg Repo Configured"
fi

if [[ $install_sharepoint == "yes" ]]; then
    # make sure all the python sharepoint modules are in place
    installSharepoint
    # assign sharepoint credentials
    configureSharepoint
fi

if [[ $SLACK_WEBHOOK ]]; then
    # assign slack name and webhook
    configureSlack
fi


if [[ $JSS_TYPE ]]; then
    # Install JSSImporter using AutoPkg install recipe
    installJSSImporter
    ${LOGGER} "JSSImporter installed."
    echo
    echo "### JSSImporter installed."
fi

if [[ $JSS_URL || $JSS_API_USER || $JSS_API_PW ]]; then
    # configure repos in com.github.autopkg
    configureJSSImporter
    ${LOGGER} "JSSImporter Configured for $JSS_TYPE Distribution Point."
    echo
    echo "### JSSImporter Configured for $JSS_TYPE Distribution Point"

else
    ${LOGGER} "JSSImporter not configured. Skipping."
    echo
    echo "### JSSImporter not configured. Skipping."
fi
