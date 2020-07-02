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

setupPrivateRepo() {
    # AutoPkg has no built-in commands for adding private repos as SSH so that you can use a key
    # This does the work. Thanks to https://www.johnkitzmiller.com/blog/using-a-private-repository-with-autopkgautopkgr/

    # clone the recipe repo if it isn't there already
    if [[ ! -d "$AUTOPKG_PRIVATE_REPO" ]]; then
        ${GIT} clone $AUTOPKG_PRIVATE_REPO_URI "$AUTOPKG_PRIVATE_REPO"
    fi

    # add to AutoPkg prefs RECIPE_REPOS
    # First check if it's already there - we can leave it alone if so!
    if ! ${PLISTBUDDY} -c "Print :RECIPE_REPOS" "${AUTOPKG_PREFS}" &>/dev/null; then
        ${PLISTBUDDY} -c "Add :RECIPE_REPOS dict" "${AUTOPKG_PREFS}"
    fi

    if ! ${PLISTBUDDY} -c "Print :RECIPE_REPOS:$AUTOPKG_PRIVATE_REPO" "${AUTOPKG_PREFS}" &>/dev/null; then
        ${PLISTBUDDY} -c "Add :RECIPE_REPOS:$AUTOPKG_PRIVATE_REPO dict" "${AUTOPKG_PREFS}"
        ${PLISTBUDDY} -c "Add :RECIPE_REPOS:$AUTOPKG_PRIVATE_REPO:URL string $AUTOPKG_PRIVATE_REPO_URI" "${AUTOPKG_PREFS}"
    fi

    # add to AutoPkg prefs RECIPE_SEARCH_DIRS
    if ! ${PLISTBUDDY} -c "Print :RECIPE_SEARCH_DIRS" "${AUTOPKG_PREFS}" &>/dev/null; then
        ${PLISTBUDDY} -c "Add :RECIPE_SEARCH_DIRS array" "${AUTOPKG_PREFS}"
    fi
    # First check if it's already there - we can leave it alone if so!
    privateRecipeID=$(${PLISTBUDDY} -c "Print :RECIPE_SEARCH_DIRS" "${AUTOPKG_PREFS}" | grep "$AUTOPKG_PRIVATE_REPO")
    if [ -z "$privateRecipeID" ]; then
        ${PLISTBUDDY} -c "Add :RECIPE_SEARCH_DIRS: string '$AUTOPKG_PRIVATE_REPO'" "${AUTOPKG_PREFS}"
    fi
}

installJSSImporter() {
    # Install JSSImporter using AutoPkg install recipe
    echo
    echo "### Downloading JSSImporter pkg from AutoPkg"
    # rtrouton-recipes required for standard JSSImporter.install.
    # grahampugh-recipes required for beta JSSImporterBeta.install.
    if [[ $use_betas == "yes" ]]; then
        ${AUTOPKG} repo-add grahampugh-recipes --prefs "$AUTOPKG_PREFS"
        ${AUTOPKG} make-override --force JSSImporterBeta.install --prefs "$AUTOPKG_PREFS"
        sleep 1
        ${AUTOPKG} run --prefs "$AUTOPKG_PREFS" -v JSSImporterBeta.install
    else
        ${AUTOPKG} repo-add rtrouton-recipes --prefs "$AUTOPKG_PREFS"
        ${AUTOPKG} make-override --force com.github.rtrouton.install.JSSImporter --prefs "$AUTOPKG_PREFS"
        sleep 1
        ${AUTOPKG} run --prefs "$AUTOPKG_PREFS" -v JSSImporter.install
    fi

}

configureJSSImporter() {
    # get URL
    if [[ "${JSS_URL}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" JSS_URL "${JSS_URL}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" JSS_URL &>/dev/null ; then
        printf '%s ' "JSS_URL required. Please enter : "
        read JSS_URL
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" JSS_URL "${JSS_URL}"
    fi

    # get API user
    if [[ "${JSS_API_USER}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_USERNAME "${JSS_API_USER}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" API_USERNAME &>/dev/null ; then
        printf '%s ' "API_USERNAME required. Please enter : "
        read JSS_API_USER
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_USERNAME "${JSS_API_USER}"
    fi

    # get API user's password
    if [[ "${JSS_API_PW}" == "-" ]]; then
        printf '%s ' "API_PASSWORD required. Please enter : "
        read -s JSS_API_PW
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_PASSWORD "${JSS_API_PW}"
    elif [[ "${JSS_API_PW}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_PASSWORD "${JSS_API_PW}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" API_PASSWORD &>/dev/null ; then
        printf '%s ' "API_PASSWORD required. Please enter : "
        read -s JSS_API_PW
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_PASSWORD "${JSS_API_PW}"
    fi

    # JSSImporter requires the Repo type for cloud instances
    if [[ "$JSS_TYPE" ]]; then
        # check if there is a JSS_REPOS array
        if ! ${PLISTBUDDY} -c "Print :JSS_REPOS" "${AUTOPKG_PREFS}" 2>/dev/null ; then
            ${PLISTBUDDY} -c "Add :JSS_REPOS array" "${AUTOPKG_PREFS}"
            echo "Added JSS_REPOS empty array"
        fi
        # check if there is an item in the JSS_REPOS array
        if ! ${PLISTBUDDY} -c "Print :JSS_REPOS:0" "${AUTOPKG_PREFS}" 2>/dev/null ; then
            ${PLISTBUDDY} -c "Add :JSS_REPOS:0 dict" "${AUTOPKG_PREFS}"
            echo "Added JSS_REPOS empty dict in array"
        fi
        # check if there is a JSS_TYPE already
        if ! ${PLISTBUDDY} -c "Print :JSS_REPOS:0:type" "${AUTOPKG_PREFS}" 2>/dev/null ; then
            ${PLISTBUDDY} -c "Add :JSS_REPOS:0:type string ${JSS_TYPE}" "${AUTOPKG_PREFS}"
            echo "Added JSS_TYPE"
        else
            ${PLISTBUDDY} -c "Set :JSS_REPOS:0:type ${JSS_TYPE}" "${AUTOPKG_PREFS}"
            echo "Reset JSS_TYPE"
        fi
        # if JSS_TYPE is a fileshare distribution point, get share name and password
        if [[ $JSS_TYPE == "SMB" || $JSS_TYPE == "AFP" ]]; then
            if [[ $JAMFREPO_NAME ]]; then 
                if ! ${PLISTBUDDY} -c "Print :JSS_REPOS:0:name" "${AUTOPKG_PREFS}" 2>/dev/null ; then
                    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:name string ${JAMFREPO_NAME}" "${AUTOPKG_PREFS}"
                    echo "Added JAMFREPO_NAME"
                else
                    ${PLISTBUDDY} -c "Set :JSS_REPOS:0:name ${JAMFREPO_NAME}" "${AUTOPKG_PREFS}"
                    echo "Reset JAMFREPO_NAME"
                fi
            elif ! ${PLISTBUDDY} -c "Print :JSS_REPOS:0:name" "${AUTOPKG_PREFS}" 2>/dev/null ; then
                printf '%s ' "JAMFREPO_NAME required. Please enter : "
                read JAMFREPO_NAME
                echo
                ${PLISTBUDDY} -c "Add :JSS_REPOS:0:name ${JAMFREPO_NAME}" "${AUTOPKG_PREFS}"
                echo "Added JAMFREPO_NAME"
            fi
            if [[ $JAMFREPO_PW ]]; then 
                if ! ${PLISTBUDDY} -c "Print :JSS_REPOS:0:password" "${AUTOPKG_PREFS}"  2>/dev/null ; then
                    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:password string ${JAMFREPO_PW}" "${AUTOPKG_PREFS}"
                    echo "Added JAMFREPO_PW"
                else
                    ${PLISTBUDDY} -c "Set :JSS_REPOS:0:password ${JAMFREPO_PW}" "${AUTOPKG_PREFS}"
                    echo "Reset JAMFREPO_PW"
                fi
            elif ! ${PLISTBUDDY} -c "Print :JSS_REPOS:0:password" "${AUTOPKG_PREFS}" 2>/dev/null ; then
                printf '%s ' "JAMFREPO_PW required. Please enter : "
                read -s JAMFREPO_PW
                echo
                ${PLISTBUDDY} -c "Add :JSS_REPOS:0:password string ${JAMFREPO_PW}" "${AUTOPKG_PREFS}"
                echo "Added JAMFREPO_NAME"
            fi
        elif  [[ $JSS_TYPE == "Local" ]]; then
            if [[ $JAMFREPO_MOUNTPOINT ]]; then 
                if ! ${PLISTBUDDY} -c "Print :JSS_REPOS:0:mount_point" "${AUTOPKG_PREFS}" 2>/dev/null ; then
                    ${PLISTBUDDY} -c "Add :JSS_REPOS:0:mount_point string ${JAMFREPO_MOUNTPOINT}" "${AUTOPKG_PREFS}"
                    echo "Added JAMFREPO_MOUNTPOINT"
               else
                    ${PLISTBUDDY} -c "Set :JSS_REPOS:0:mount_point ${JAMFREPO_MOUNTPOINT}" "${AUTOPKG_PREFS}"
                    echo "Reset JAMFREPO_MOUNTPOINT"
                fi
            elif ! ${PLISTBUDDY} -c "Print :JSS_REPOS:0:mount_point" "${AUTOPKG_PREFS}" 2>/dev/null ; then
                printf '%s ' "JAMFREPO_MOUNTPOINT required. Please enter : "
                read JAMFREPO_MOUNTPOINT
                echo
                ${PLISTBUDDY} -c "Add :JSS_REPOS:0:mount_point string ${JAMFREPO_MOUNTPOINT}" "${AUTOPKG_PREFS}"
                echo "Added JAMFREPO_MOUNTPOINT"
            fi
        fi
    fi
}

installSharepoint() {
    # We need some python modules for the Sharepointer stuff to work
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
}

configureSharepoint() {
    # get SP URL
    if [[ "${SP_URL}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_URL "${SP_URL}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SP_URL &>/dev/null ; then
        printf '%s ' "SP_URL required. Please enter : "
        read SP_URL
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_URL "${SP_URL}"
    fi

    # get SP API user
    if [[ "${SP_USER}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_USER "${SP_USER}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SP_USER &>/dev/null ; then
        printf '%s ' "SP_USER required. Please enter : "
        read SP_USER
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_USER "${SP_USER}"
    fi

    # get SP API user's password
    if [[ "${SP_PASS}" == "-" ]]; then
        printf '%s ' "SP_PASS required. Please enter : "
        read -s SP_PASS
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_PASS "${SP_PASS}"
    elif [[ "${SP_PASS}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_PASS "${SP_PASS}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SP_PASS &>/dev/null ; then
        printf '%s ' "SP_PASS required. Please enter : "
        read -s SP_PASS
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_PASS "${SP_PASS}"
    fi
}

configureSlack() {
    # get Slack user and webhook
    if [[ "${SLACK_USERNAME}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SLACK_USERNAME "${SLACK_USERNAME}"
        echo "### Wrote SLACK_USERNAME $SLACK_USERNAME to $AUTOPKG_PREFS"
    fi
    if [[ "${SLACK_WEBHOOK}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SLACK_WEBHOOK "${SLACK_WEBHOOK}"
        echo "### Wrote SLACK_WEBHOOK $SLACK_WEBHOOK to $AUTOPKG_PREFS"
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

# get arguments
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
            [[ $AUTOPKG_PREFS != *".plist" ]] && AUTOPKG_PREFS="${AUTOPKG_PREFS}.plist"
            echo "AUTOPKG_PREFS : $AUTOPKG_PREFS"
        ;;
        --private-repo)
            shift
            AUTOPKG_PRIVATE_REPO="$1"
        ;;
        --private-repo-url)
            shift
            AUTOPKG_PRIVATE_REPO_URI="$1"
        ;;
        --recipe-list)
            shift
            AUTOPKG_RECIPE_LIST="$1"
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
        --sp-url)
            shift
            SP_URL="$1"
        ;;
        --slack-webhook)
            shift
            SLACK_WEBHOOK="$1"
        ;;
        --slack-user)
            shift
            SLACK_USERNAME="$1"
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
    AUTOPKG_PREFS="$HOME/Library/Preferences/com.github.autopkg.plist"
fi

# check that the prefs exist and are valid
if /usr/bin/plutil -lint "$AUTOPKG_PREFS" ; then 
    echo "$AUTOPKG_PREFS is a valid plist"
else
    echo "$AUTOPKG_PREFS is not a valid plist! Creating a new one:"
    # create a new one with basic entries and take it from there
    rm -f "$AUTOPKG_PREFS" ||:
    ${DEFAULTS} write "${AUTOPKG_PREFS}" GIT_PATH "$(which git)"
    echo "### Wrote GIT_PATH $(which git) to $AUTOPKG_PREFS"
fi

# ensure untrusted recipes fail
${DEFAULTS} write "$AUTOPKG_PREFS" FAIL_RECIPES_WITHOUT_TRUST_INFO -bool true
echo "### Wrote FAIL_RECIPES_WITHOUT_TRUST_INFO true to $AUTOPKG_PREFS"

# add Slack credentials if anything supplied
if [[ $SLACK_USERNAME || $SLACK_WEBHOOK ]]; then
    configureSlack
fi

## AutoPkg repos:
# Add private repo if set: this should be first
if [[ $AUTOPKG_PRIVATE_REPO && $AUTOPKG_PRIVATE_REPO_URI ]]; then
    setupPrivateRepo
    ${LOGGER} "Private AutoPkg Repo Configured"
    echo
    echo "### Private AutoPkg Repo Configured"
fi

# jss-recipes required for easy access to icons and descriptions.
# Add more recipe repos here if required.
if [[ -f "$AUTOPKG_REPO_LIST" ]]; then
    read -r -d '' AUTOPKGREPOS < "$AUTOPKG_REPO_LIST"
else
    read -r -d '' AUTOPKGREPOS <<ENDMSG
recipes
jss-recipes
ENDMSG
fi

# ensure all repos associated with an inputted recipe list are added
if [[ -f "$AUTOPKG_RECIPE_LIST" ]]; then
    while read recipe ; do 
        ${AUTOPKG} info -p "${recipe}" --prefs "$AUTOPKG_PREFS"
    done < "$AUTOPKG_RECIPE_LIST"
fi

# Add AutoPkg repos (checks if already added)
${AUTOPKG} repo-add ${AUTOPKGREPOS} --prefs "$AUTOPKG_PREFS"

# Update AutoPkg repos (if the repos were already there no update would otherwise happen)
${AUTOPKG} repo-update all --prefs "$AUTOPKG_PREFS"

${LOGGER} "AutoPkg Repos Configured"
echo
echo "### AutoPkg Repos Configured"

if [[ $install_sharepoint == "yes" ]]; then
    # make sure all the python sharepoint modules are in place
    installSharepoint
    # assign sharepoint credentials
    configureSharepoint
fi

if [[ $JSS_TYPE ]]; then
    # Install JSSImporter using AutoPkg install recipe
    installJSSImporter
    ${LOGGER} "JSSImporter installed."
    echo
    echo "### JSSImporter installed."
fi

if [[ $JSS_TYPE == "SMB" || $JSS_TYPE == "AFP" || $JSS_TYPE == "Local" ]]; then
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
