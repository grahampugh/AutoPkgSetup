#!/bin/bash

# autopkg-setup.sh
# by Graham Pugh

# autopkg-setup automates the installation of the latest version
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
    echo "   [setup] Installing the command line tools..."
    echo
    zsh ./XcodeCLTools-install.zsh
}

installAutoPkg() {
    # Get AutoPkg
    # thanks to Nate Felton
    # Inputs: 1. $USERHOME
    if [[ $use_betas == "yes" ]]; then
        AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases | python3 -c 'import json,sys;obj=json.load(sys.stdin);print(obj[0]["assets"][0]["browser_download_url"])')
    else
        AUTOPKG_LATEST=$(curl https://api.github.com/repos/autopkg/autopkg/releases/latest | python3 -c 'import json,sys;obj=json.load(sys.stdin);print(obj["assets"][0]["browser_download_url"])')
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

configureJamfUploader() {
    # configure JamfUploader
    ${DEFAULTS} write "$AUTOPKG_PREFS" JSS_URL "${JSS_URL}"

    # get API user
    if [[ "${JSS_API_USER}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_USERNAME "${JSS_API_USER}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" API_USERNAME &>/dev/null ; then
        printf '%s ' "API_USERNAME required. Please enter : "
        read -r JSS_API_USER
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_USERNAME "${JSS_API_USER}"
    fi

    # get API user's password
    if [[ "${JSS_API_PW}" == "-" ]]; then
        printf '%s ' "API_PASSWORD required. Please enter : "
        read -r -s JSS_API_PW
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_PASSWORD "${JSS_API_PW}"
    elif [[ "${JSS_API_PW}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_PASSWORD "${JSS_API_PW}"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" API_PASSWORD &>/dev/null ; then
        printf '%s ' "API_PASSWORD required. Please enter : "
        read -r -s JSS_API_PW
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" API_PASSWORD "${JSS_API_PW}"
    fi

    # JamfUploader requires simple defaults keys for the repo
    if [[ "${SMB_URL}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SMB_URL "${SMB_URL}"
    fi
    if [[ "${SMB_USERNAME}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SMB_USERNAME "${SMB_USERNAME}"
    fi
    if [[ "${SMB_PASSWORD}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SMB_PASSWORD "${SMB_PASSWORD}"
    fi
}

configureJSSImporter() {
    # JSSImporter requires the Repo type for cloud and local instances, but not SMB or AFP
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
                read -r JAMFREPO_NAME
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
                read -r -s JAMFREPO_PW
                echo
                ${PLISTBUDDY} -c "Add :JSS_REPOS:0:password string ${JAMFREPO_PW}" "${AUTOPKG_PREFS}"
                echo "Added JAMFREPO_PW"
            fi
        else
            # check if there is a JSS_TYPE already
            if ! ${PLISTBUDDY} -c "Print :JSS_REPOS:0:type" "${AUTOPKG_PREFS}" 2>/dev/null ; then
                ${PLISTBUDDY} -c "Add :JSS_REPOS:0:type string ${JSS_TYPE}" "${AUTOPKG_PREFS}"
                echo "Added JSS_TYPE"
            else
                ${PLISTBUDDY} -c "Set :JSS_REPOS:0:type ${JSS_TYPE}" "${AUTOPKG_PREFS}"
                echo "Reset JSS_TYPE"
            fi
        fi
        if [[ $JSS_TYPE == "Local" ]]; then
            # add the mountpoint
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
                read -r JAMFREPO_MOUNTPOINT
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
    /usr/local/autopkg/python -m pip install requests-ntlm2 shareplum --user
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
        echo "### Wrote SP_URL $SP_URL to $AUTOPKG_PREFS"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SP_URL &>/dev/null ; then
        printf '%s ' "SP_URL required. Please enter : "
        read -r SP_URL
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_URL "${SP_USER}"
        echo "### Wrote SP_URL $SP_URL to $AUTOPKG_PREFS"
    fi

    # get SP API user
    if [[ "${SP_USER}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_USER "${SP_USER}"
        echo "### Wrote SP_USER $SP_USER to $AUTOPKG_PREFS"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SP_USER &>/dev/null ; then
        printf '%s ' "SP_USER required. Please enter : "
        read -r SP_USER
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_USER "${SP_USER}"
        echo "### Wrote SP_USER $SP_USER to $AUTOPKG_PREFS"
    fi

    # get SP API user's password
    if [[ "${SP_PASS}" == "-" ]]; then
        printf '%s ' "SP_PASS required. Please enter : "
        read -r -s SP_PASS
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_PASS "${SP_PASS}"
        echo "### Wrote SP_PASS to $AUTOPKG_PREFS"
    elif [[ "${SP_PASS}" ]]; then
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_PASS "${SP_PASS}"
        echo "### Wrote SP_PASS to $AUTOPKG_PREFS"
    elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SP_PASS &>/dev/null ; then
        printf '%s ' "SP_PASS required. Please enter : "
        read -r -s SP_PASS
        echo
        ${DEFAULTS} write "$AUTOPKG_PREFS" SP_PASS "${SP_PASS}"
        echo "### Wrote SP_PASS to $AUTOPKG_PREFS"
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

# declare array for recipe lists
AUTOPKG_RECIPE_LISTS=()

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
        --prefs)
            shift
            AUTOPKG_PREFS="$1"
            [[ $AUTOPKG_PREFS == "/"* ]] || AUTOPKG_PREFS="$(pwd)/${AUTOPKG_PREFS}"
            [[ $AUTOPKG_PREFS != *".plist" ]] && AUTOPKG_PREFS="${AUTOPKG_PREFS}.plist"
            echo "AUTOPKG_PREFS : $AUTOPKG_PREFS"
        ;;
        --replace-prefs) replace_prefs="yes"
        ;;
        --github-token)
            shift
            GITHUB_TOKEN="$1"
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
            AUTOPKG_RECIPE_LISTS+=("$1")
        ;;
        --repo-list)
            shift
            AUTOPKG_REPO_LIST="$1"
        ;;
        # --prod-repo-list)
        #     shift
        #     AUTOPKG_PROD_REPO_LIST="$1"
        # ;;
        --jss-type)
            shift
            JSS_TYPE="$1"
        ;;
        --jss-repo) # used by JSSImporter only
            shift
            JAMFREPO_NAME="$1"
        ;;
        --jss-repo-url) # used by JamfUploader only
            shift
            SMB_URL="$1"
        ;;
        --jss-repo-user) # used by JamfUploader only
            shift
            SMB_USERNAME="$1"
        ;;
        --jss-repo-pass)
            shift
            JAMFREPO_PW="$1"
            SMB_PASSWORD="$1"
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
        --slack-webhook)
            shift
            SLACK_WEBHOOK="$1"
        ;;
        --slack-user)
            shift
            SLACK_USERNAME="$1"
        ;;
        --sp-url)
            shift
            SP_URL="$1"
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
./autopkg_setup.sh                           

-h | --help             Displays this text
-f | --force            Force the re-installation of the latest AutoPkg 
-b | --betas            Install betas of AutoPkg and JSSImporter
-p | --prefs *          Path to the preferences plist
                        (default is /Library/Preferences/com.github.autopkg.plist)

--replace-prefs         Delete the prefs file and rebuild from scratch
--github-token *        A GitHub token - required to prevent hitting API limits

--private-repo *        Path to a private repo
--private-repo-url *    The private repo url

--repo-list *           Path to a repo-list file. All repos will be added to the prefs file.

--recipe-list *         Path to a recipe list. If this method is used, all parent repos
                        are added, but the recipes must be in a repo that is already installed.

--jss-url *             URL of the Jamf server
--jss-user *            API account username
--jss-pass *            API account password

JSSImporter settings:

--jss-type *            Type of Jamf server. Use SMB, AFP, Local or CDP
--jss-repo *            Name of FileShare Distribution Point (SMB/AFP)
--jss-repo-pass *       Password of account that has access to the DP
--jss-repo-mount *      Mount point if using Local repo

JamfUploader settings:

--jss-repo-url *        URL of the FileShare Distribution Point
--jss-repo-user *       Username of account that has access to the DP
--jss-repo-pass *       Password of account that has access to the DP

Slack settings:

--slack-webhook *       Slack webhook
--slack-user *          A display name for the Slack notifications

SharePoint settings:
--sp-url *              URL of the SharePoint site
--sp-user *             Username of the SharePoint API account
--sp-pass *             Password of the SharePoint API account

"
            exit 0
        ;;
    esac
    shift
done

# Check for Command line tools.
if ! xcode-select -p >/dev/null 2>&1 ; then
    installCommandLineTools
fi

# check CLI tools are functional
if ! $GIT --version >/dev/null 2>&1 ; then
    installCommandLineTools
fi

# double-check CLI tools are functional
if ! $GIT --version >/dev/null 2>&1 ; then
    $LOGGER "ERROR: Xcode Command Line Tools failed to install"
    echo
    echo "### ERROR: Xcode Command Line Tools failed to install."
    exit 1
else
    $LOGGER "Xcode Command Line Tools installed and functional"
    echo
    echo "### Xcode Command Line Tools installed and functional"
fi

# Get AutoPkg if not already installed
if [[ ! -f "${AUTOPKG}" || $force_autopkg_update == "yes" ]]; then
    installAutoPkg "${HOME}"
    ${LOGGER} "AutoPkg installed and secured"
    echo
    echo "### AutoPkg installed and secured"
fi

# read the supplied prefs file or else use the default
if [[ ! $AUTOPKG_PREFS ]]; then
    AUTOPKG_PREFS="$HOME/Library/Preferences/com.github.autopkg.plist"
fi

# kill any existing prefs
if [[ $replace_prefs ]]; then
    rm -f "$AUTOPKG_PREFS" ||:
fi

# add the GIT path to the prefs
${DEFAULTS} write "${AUTOPKG_PREFS}" GIT_PATH "$(which git)"
echo "### Wrote GIT_PATH $(which git) to $AUTOPKG_PREFS"

# add the GitHub token to the prefs
if [[ $GITHUB_TOKEN ]]; then
    ${DEFAULTS} write "${AUTOPKG_PREFS}" GITHUB_TOKEN "$GITHUB_TOKEN"
    echo "### Wrote GITHUB_TOKEN to $AUTOPKG_PREFS"
fi

# ensure untrusted recipes fail
${DEFAULTS} write "$AUTOPKG_PREFS" FAIL_RECIPES_WITHOUT_TRUST_INFO -bool true
echo "### Wrote FAIL_RECIPES_WITHOUT_TRUST_INFO true to $AUTOPKG_PREFS"

# add Slack credentials if anything supplied
if [[ $SLACK_USERNAME || $SLACK_WEBHOOK ]]; then
    configureSlack
fi

# Add recipe repos to the prefs.
if [[ -f "$AUTOPKG_REPO_LIST" ]]; then
    read -r -d '' AUTOPKGREPOS < "$AUTOPKG_REPO_LIST"
else
    read -r -d '' AUTOPKGREPOS <<ENDMSG
recipes
ENDMSG
fi

# Add AutoPkg repos (checks if already added)
${AUTOPKG} repo-add ${AUTOPKGREPOS} --prefs "$AUTOPKG_PREFS"

echo "Added $AUTOPKGREPOS to the prefs file"

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

if [[ $SP_URL ]]; then
    # make sure all the python sharepoint modules are in place
    installSharepoint
    # assign sharepoint credentials
    configureSharepoint
fi

if [[ $JSS_URL ]]; then
    # Configure JamfUploader
    configureJamfUploader
    ${LOGGER} "JamfUploader configured."
    echo
    echo "### JamfUploader configured."
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

# ensure all repos associated with an inputted recipe list(s) are added
if [ ${#AUTOPKG_RECIPE_LISTS[@]} -ne 0 ]; then
    for file in "${AUTOPKG_RECIPE_LISTS[@]}"; do
        while read -r recipe ; do 
            ${AUTOPKG} info -p "${recipe}" --prefs "$AUTOPKG_PREFS"
        done < "$file"
    done

    ${LOGGER} "AutoPkg Repos for all parent recipes added"
    echo
    echo "### AutoPkg Repos for all parent recipes added"
fi

