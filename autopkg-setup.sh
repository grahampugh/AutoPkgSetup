#!/bin/bash

# autopkg-setup.sh
# by Graham Pugh

# autopkg-setup automates the installation of the latest version
# of AutoPkg, optimised for JamfUploader

# Acknowledgements
# Excerpts from https://github.com/grahampugh/run-munki-run
# which in turn borrows from https://github.com/tbridge/munki-in-a-box

# -------------------------------------------------------------------------------------- #
# designed to be used with prefs files that autopkg can run with the --prefs option
# These are easy to make with defaults commands or using YAML. 
# Store them in a private git account.
# This script will ensure that all repos are added to the server.
# -------------------------------------------------------------------------------------- #
## No editing required below here


rootCheck() {
    # Check that the script is NOT running as root
    current_user=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
    if [[ $EUID -eq 0 ]]; then
        echo "### This script is NOT MEANT to run as root."
        echo "This script is meant to be run as an admin user."
        echo "Please run without sudo."
        echo
        exit 4 # Running as root.
    elif [[ ! -f "${AUTOPKG}" || $force_autopkg_update == "yes" ]]; then
        if ! /usr/sbin/dseditgroup -o checkmember -m "$current_user" admin ; then
            echo "### This script is meant to be run as an admin user."
            echo "Please use a different account or promote this account to admin while this script runs"
            echo "(the account can be demoted after AutoPkg is installed)."
            echo
            exit 5 # Running as a standard user.
        fi
    fi
}

installCommandLineTools() {
    # Installing the Xcode command line tools on 10.10+
    # This section written by Rich Trouton.
    echo "### Installing the command line tools..."
    echo
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
        # softwareupdate -i "$cmd_line_tools" --verbose
        /usr/bin/osascript -e 'do shell script "softwareupdate -i "'"$cmd_line_tools"'" --verbose" with administrator privileges'
    else
        echo "Download not found"
    fi

    # remove the temp file
    if [[ -f "$cmd_line_tools_temp_file" ]]; then
        rm "$cmd_line_tools_temp_file"
    fi
}

installAutoPkg() {
    # Get AutoPkg
    # thanks to Nate Felton
    # Inputs: 1. $USERHOME
    echo "### Downloading AutoPkg installer package..."
    echo
    if [[ $use_beta == "yes" ]]; then
        AUTOPKG_LATEST=$(curl -sL -H "Accept: application/json" "https://api.github.com/repos/autopkg/autopkg/releases/tags/v3.0.0RC1" | awk -F '"' '/browser_download_url/ { print $4; exit }')
    else
        AUTOPKG_LATEST=$(curl -sL -H "Accept: application/json" "https://api.github.com/repos/autopkg/autopkg/releases/latest" | awk -F '"' '/browser_download_url/ { print $4; exit }')
    fi
    if ! /usr/bin/curl -L "${AUTOPKG_LATEST}" -o "/tmp/autopkg-latest.pkg"; then
        echo "### ERROR: could not obtain AutoPkg installer package..."
        echo
        exit 1
    fi

    echo "### Installing AutoPkg..."
    echo "ALERT: REQUIRES ADMIN RIGHTS - please enter account password"
    echo
    echo "### Prompting for administrator credentials to install AutoPkg..."
    /usr/bin/osascript -e 'do shell script "installer -pkg /tmp/autopkg-latest.pkg -target /" with administrator privileges'

    autopkg_version=$(${AUTOPKG} version)

    ${LOGGER} "AutoPkg $autopkg_version Installed"
    echo
    echo "### AutoPkg $autopkg_version Installed"
    echo

    # Clean Up When Done
    # rm "/tmp/autopkg-latest.pkg"
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

        # get SMB user's password
        if [[ "${SMB_USERNAME}" ]]; then
            ${DEFAULTS} write "$AUTOPKG_PREFS" SMB_USERNAME "${SMB_USERNAME}"
        elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SMB_USERNAME &>/dev/null ; then
            printf '%s ' "SMB_USERNAME required. Please enter : "
            read -r SMB_USERNAME
            echo
            ${DEFAULTS} write "$AUTOPKG_PREFS" SMB_USERNAME "${SMB_USERNAME}"
        fi

        # get SMB user's password
        if [[ "${SMB_PASSWORD}" == "-" ]]; then
            printf '%s ' "SMB_PASSWORD required. Please enter : "
            read -r -s SMB_PASSWORD
            echo
            ${DEFAULTS} write "$AUTOPKG_PREFS" SMB_PASSWORD "${SMB_PASSWORD}"
        elif [[ "${SMB_PASSWORD}" ]]; then
            ${DEFAULTS} write "$AUTOPKG_PREFS" SMB_PASSWORD "${SMB_PASSWORD}"
        elif ! ${DEFAULTS} read "$AUTOPKG_PREFS" SMB_PASSWORD &>/dev/null ; then
            printf '%s ' "SMB_PASSWORD required. Please enter : "
            read -r -s SMB_PASSWORD
            echo
            ${DEFAULTS} write "$AUTOPKG_PREFS" SMB_PASSWORD "${SMB_PASSWORD}"
        fi
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

# default for failing unverified recipes
fail_recipes="yes"

# get arguments
while test $# -gt 0
do
    case "$1" in
        -f|--force) force_autopkg_update="yes"
        ;;
        -b|--beta)
            force_autopkg_update="yes"
            use_beta="yes"
        ;;
        -x|--fail)
            fail_recipes="no"
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
        --smb-url)
            shift
            SMB_URL="$1"
        ;;
        --smb-user)
            shift
            SMB_USERNAME="$1"
        ;;
        --smb-pass)
            shift
            SMB_PASSWORD="$1"
        ;;
        --jamf-uploader-repo)
            jamf_upload_repo="yes"
        ;;
        *)
            echo "
Usage:
./autopkg_setup.sh                           

-h | --help             Displays this text
-f | --force            Force the re-installation of the latest AutoPkg 
-b | --beta            force the installation of the pre-relased version of AutoPkg 
-x | --fail             Don't fail runs if not verified
-j | --jcds2-mode        Set to jcds2_mode
-p | --prefs *          Path to the preferences plist
                        (default is /Library/Preferences/com.github.autopkg.plist)

--replace-prefs         Delete the prefs file and rebuild from scratch
--github-token *        A GitHub token - required to prevent hitting API limits

--private-repo *        Path to a private repo
--private-repo-url *    The private repo url

--repo-list *           Path to a repo-list file. All repos will be added to the prefs file.

--recipe-list *         Path to a recipe list. If this method is used, all parent repos
                        are added, but the recipes must be in a repo that is already installed.

JamfUploader settings:

--jss-url *             URL of the Jamf server
--jss-user *            API account username
--jss-pass *            API account password

--smb-url *             URL of the FileShare Distribution Point
--smb-user *            Username of account that has access to the DP
--smb-pass *            Password of account that has access to the DP

--jamf-uploader-repo    Use the grahampugh/jamf-upload repo instead of autopkg/grahampugh-recipes 
                        for JamfUploader processors (effectively JamfUploader beta access)

Slack settings:

--slack-webhook *       Slack webhook
--slack-user *          A display name for the Slack notifications

"
            exit 0
        ;;
    esac
    shift
done

# root check
rootCheck

# Check for Command line tools.
if ! xcode-select -p >/dev/null 2>&1 ; then
    echo "Xcode Command Line Tools not found, proceeding to install."
    installCommandLineTools
else
    echo "Xcode Command Line Tools found."
fi

# check CLI tools are functional
if ! $GIT --version >/dev/null 2>&1 ; then
    echo "Xcode Command Line Tools not functional, proceeding to install."
    installCommandLineTools
else
    echo "Xcode Command Line Tools functional."
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
    GITHUB_TOKEN_PATH="$HOME/Library/AutoPkg/gh_token"
    echo "$GITHUB_TOKEN" > "$GITHUB_TOKEN_PATH"
    echo "### Wrote GITHUB_TOKEN to $GITHUB_TOKEN_PATH"
    ${DEFAULTS} write "${AUTOPKG_PREFS}" GITHUB_TOKEN_PATH "$GITHUB_TOKEN_PATH"
    echo "### Wrote GITHUB_TOKEN_PATH to $AUTOPKG_PREFS"
fi

# ensure untrusted recipes fail
if [[ $fail_recipes == "no" ]]; then
    ${DEFAULTS} write "$AUTOPKG_PREFS" FAIL_RECIPES_WITHOUT_TRUST_INFO -bool false
    echo "### Wrote FAIL_RECIPES_WITHOUT_TRUST_INFO false to $AUTOPKG_PREFS"
else
    ${DEFAULTS} write "$AUTOPKG_PREFS" FAIL_RECIPES_WITHOUT_TRUST_INFO -bool true
    echo "### Wrote FAIL_RECIPES_WITHOUT_TRUST_INFO true to $AUTOPKG_PREFS"
fi

# set jcds2_mode
if [[ $jcds2_mode == "yes" ]]; then
    ${DEFAULTS} write "$AUTOPKG_PREFS" jcds2_mode -bool true
    echo "### Wrote jcds2_mode true to $AUTOPKG_PREFS"
elif ${DEFAULTS} read com.github.autopkg jcds2_mode 2>/dev/null; then
    ${DEFAULTS} delete "$AUTOPKG_PREFS" jcds2_mode
fi

# add Slack credentials if anything supplied
if [[ $SLACK_USERNAME || $SLACK_WEBHOOK ]]; then
    configureSlack
fi

# ensure we have the recipe list dictionary and array
if ! ${DEFAULTS} read "$AUTOPKG_PREFS" RECIPE_SEARCH_DIRS 2>/dev/null; then
    ${DEFAULTS} write "$AUTOPKG_PREFS" RECIPE_SEARCH_DIRS -array
fi
if ! ${DEFAULTS} read "$AUTOPKG_PREFS" RECIPE_REPOS 2>/dev/null; then
    ${DEFAULTS} write "$AUTOPKG_PREFS" RECIPE_REPOS -dict
fi

# build the repo list
AUTOPKG_REPOS=()

# If using the jamf-upload repo, we have to make sure it's above grahampugh-recipes in the search
if [[ "$jamf_upload_repo" == "yes" ]]; then
    if autopkg list-repos --prefs "$AUTOPKG_PREFS" | grep grahampugh-recipes; then
        ${AUTOPKG} repo-delete grahampugh-recipes --prefs "$AUTOPKG_PREFS"
    fi
    AUTOPKG_REPOS+=("grahampugh/jamf-upload")
else
    if autopkg list-repos --prefs "$AUTOPKG_PREFS" | grep grahampugh/jamf-upload; then
        ${AUTOPKG} repo-delete grahampugh/jamf-upload --prefs "$AUTOPKG_PREFS"
    fi
fi

# always add grahampugh-recipes
AUTOPKG_REPOS+=("grahampugh-recipes")

# add more if there is a repo-list supplied
if [[ -f "$AUTOPKG_REPO_LIST" ]]; then
    while IFS= read -r; do
        repo="$REPLY"
        AUTOPKG_REPOS+=("$repo")
    done < "$AUTOPKG_REPO_LIST"
fi

# Add AutoPkg repos (checks if already added)
for r in "${AUTOPKG_REPOS[@]}"; do
    if ${AUTOPKG} repo-add "$r" --prefs "$AUTOPKG_PREFS" 2>/dev/null; then
        echo "Added $r to $AUTOPKG_PREFS"
    else
        echo "ERROR: could not add $r to $AUTOPKG_PREFS"
    fi
done

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

if [[ $JSS_URL ]]; then
    # Configure JamfUploader
    configureJamfUploader
    ${LOGGER} "JamfUploader configured."
    echo
    echo "### JamfUploader configured."
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

