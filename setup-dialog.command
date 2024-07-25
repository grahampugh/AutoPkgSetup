#!/bin/bash

: <<DESCRIPTION
Script design inspired by Kyle Hoare @ Jamf.
DESCRIPTION

##############################################################
# Global Variables
##############################################################

current_user=$(/usr/sbin/scutil <<< "show State:/Users/ConsoleUser" | /usr/bin/awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}')
working_dir=$(dirname "$0")
autopkgsetup="$working_dir/autopkg-setup.sh"

# ensure log file is writable
dialog_log=$(/usr/bin/mktemp /var/tmp/dialog.XXX)
echo "Creating dialog log ($dialog_log)..."
/usr/bin/touch "$dialog_log"
/usr/sbin/chown "${current_user}:wheel" "$dialog_log"
/bin/chmod 666 "$dialog_log"

# swiftDialog variables
dialog_app="/Library/Application Support/Dialog/Dialog.app"
dialog_bin="/usr/local/bin/dialog"
dialog_output="/var/tmp/dialog.json"

tmpdir="/tmp"

##############################################################
# Functions
##############################################################

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

##############################################################
# Check if SwiftDialog is installed
##############################################################

dialog_check() {
    # URL to get latest swift dialog
    swiftdialog_api_url="https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest"
    # obtain the download URL
    dialog_download_url=$(curl -sL -H "Accept: application/json" "$swiftdialog_api_url" | awk -F '"' '/browser_download_url/ { print $4; exit }')

    if ! command -v "$dialog_bin" >/dev/null ; then
        echo "SwiftDialog is not installed. App will be installed now....."
        dialog_install
    else
        echo "SwiftDialog is installed. Checking installed version....."
        
        dialog_installed_version=$("$dialog_bin" -v | sed 's/\.[0-9]*$//')
        
        # obtain the tag
        dialog_latest_version=$(curl -sL -H "Accept: application/json" "$swiftdialog_api_url" | awk -F '"' '/tag_name/ { print $4; exit }')
        if [[ ! $dialog_latest_version ]]; then
            echo "Could not obtain latest version information, proceeding without check..."
        elif [[ "$dialog_installed_version" != "${dialog_latest_version//v/}" ]]; then
            echo "Dialog needs updating (v$dialog_installed_version older than $dialog_latest_version)"
            dialog_install
            sleep 3
        else
            echo "Dialog is up to date. Continuing...."
        fi
    fi
}

dialog_install() {

    # install
    if /usr/bin/curl -L "$dialog_download_url" -o "$tmpdir/dialog.pkg" ; then
        if sudo installer -pkg "$tmpdir/dialog.pkg" -target / ; then
            dialog_string=$("$dialog_bin" --version)
        else
            echo "swiftDialog installation failed"
            exit 1
        fi
    else
        echo "swiftDialog download failed"
        exit 1
    fi
    # check it did actually get downloaded
    if [[ -d "$dialog_app" && -f "$dialog_bin" ]]; then
        echo "swiftDialog v$dialog_string is installed"
    else
        echo "Could not download swiftDialog."
        exit 1
    fi

    /bin/rm "$tmpdir/dialog.pkg" ||:
}

##############################################################
# This function sends a command to our command file, and sleeps briefly to avoid race conditions
##############################################################

dialog_command()
{
    echo "$@" >> "$dialog_log" 2>/dev/null & sleep 0.1
}

dialog_command_with_output()
{
    "$dialog_bin" "$@" 2>/dev/null > "$dialog_output" & sleep 0.1
}

run_dialog() {
dialog_args=(
        --commandfile
        "$dialog_log"
        --title "AutoPkg Setup Wizard"
        --position centre
        --moveable
        --icon "https://avatars.githubusercontent.com/u/5170557?s=200&v=4"
        --message "Choose the installation options below.  \n\nYou can optionally supply a Jamf Pro URL, API username and password below. This is not required but will set up AutoPkg with a default JSS." \
        --button1text "Continue"
        --button2text "Quit"
        --alignment left
        --infobox '[github.com/autopkg/autopkg](https://github.com/autopkg/autopkg)'
        --messagefont 'name=Arial,size=16'
        --textfield 'JAMF URL,prompt=https://example.jamfcloud.com'
        --textfield 'JAMF Username,prompt='
        --textfield 'JAMF Password,secure'
        --textfield 'GitHub Token,prompt='
        --checkbox "Allow recipes to run without trust information"
        --checkbox "Force AutoPkg reinstallation"
        --checkbox "Install AutoPkg beta version"
        --checkbox "Use jamf-upload repo (beta)"
        --checkboxstyle switch
        --height 500
        --json
        --ontop
    )
    echo "quit:" >> "$dialog_log"
    "$dialog_bin" "${dialog_args[@]}" 2>/dev/null > "$dialog_output"
    if [[ $? -eq 2 ]]; then
        echo "User cancelled dialog so exiting..."
        exit 0
    fi
}

progress_dialog() {
    # show progress
    dialog_args=(
        --commandfile
        "$dialog_log"
        --title "AutoPkg Setup Wizard"
        --position centre
        --moveable
        --icon "https://avatars.githubusercontent.com/u/5170557?s=200&v=4"
        --message "Installation is proceeding...\n\nDepending on the options chosen, this will\n\n* Check that Xcode Command Line Tools are installed\n* Install or update AutoPkg\n* Set the path to Git in the AutoPkg preference file\n* Set recipes to fail or proceed if untrusted\n* Add the jamf-upload and grahampugh-recipes repos\n* Update all repos"
        --button1disabled
        --progress 1
        --alignment left
        --infobox '[github.com/autopkg/autopkg](https://github.com/autopkg/autopkg)'
        --messagefont 'name=Arial,size=16'
        --ontop
    )
    "$dialog_bin" "${dialog_args[@]}" 2>/dev/null & sleep 0.1

    echo "progresstext: Installing and configuring AutoPkg" >> "$dialog_log"
    echo  "progress: 0" >> "$dialog_log"
}

done_dialog() {
    # done dialog
    dialog_args=(
        --commandfile
        "$dialog_log"
        --title "AutoPkg Setup Wizard"
        --position centre
        --moveable
        --icon "https://avatars.githubusercontent.com/u/5170557?s=200&v=4"
        --message "Installation is now complete." \
        --button1text "OK"
        --alignment left
        --infobox '[github.com/autopkg/autopkg](https://github.com/autopkg/autopkg)'
        --messagefont 'name=Arial,size=16'
        --ontop
    )
    echo "quit:" >> "$dialog_log" & sleep 0.1
    "$dialog_bin" "${dialog_args[@]}" 2>/dev/null
}

rootCheck
dialog_check
run_dialog

##############################################################
# Gather information from the dialog
##############################################################

# TEMP
cat "$dialog_output"
echo
# TEMP

JSS_URL=$(plutil -extract "JAMF URL" raw "$dialog_output" 2>/dev/null)
JSS_API_USER=$(plutil -extract "JAMF Username" raw "$dialog_output" 2>/dev/null)
JSS_API_PW=$(plutil -extract "JAMF Password" raw "$dialog_output" 2>/dev/null)
GITHUB_TOKEN=$(plutil -extract "GitHub Token" raw "$dialog_output" 2>/dev/null)
FORCE_AUTOPKG=$(plutil -extract "Force AutoPkg reinstallation" raw "$dialog_output")
INSTALL_AUTOPKG_BETA=$(plutil -extract "Install AutoPkg beta version" raw "$dialog_output")
DO_NOT_FAIL_RECIPES_WITHOUT_TRUST_INFO=$(plutil -extract "Allow recipes to run without trust information" raw "$dialog_output")
JAMFUPLOAD_REPO=$(plutil -extract "Use jamf-upload repo (beta)" raw "$dialog_output")

# if [[ $USER == "" ]] || [[ $PASSWORD == "" ]] || [[ $URL == "" ]]; then
#     echo "Aborting"
#     exit 1
# fi

##############################################################
# Assemble autopkg-setup.sh options
##############################################################

args=()

if [[ $JSS_URL ]]; then
    echo "reading JSS URL"
    args+=("--jss-url")
    args+=("$JSS_URL")
fi
if [[ $JSS_API_USER ]]; then
    echo "reading JSS User"
    args+=("--jss-user")
    args+=("$JSS_API_USER")
fi
if [[ $JSS_API_PW ]]; then
    echo "reading JSS Password"
    args+=("--jss-pass")
    args+=("$JSS_API_PW")
fi
if [[ $GITHUB_TOKEN ]]; then
    echo "reading GitHub Token"
    args+=("--github-token")
    args+=("$GITHUB_TOKEN")
fi
if [[ $FORCE_AUTOPKG == "true" ]]; then
    echo "setting Force AutoPkg reinstallation"
    args+=("--force")
fi
if [[ $INSTALL_AUTOPKG_BETA == "true" ]]; then
    echo "setting Install AutoPkg beta version"
    args+=("--beta")
fi
if [[ $DO_NOT_FAIL_RECIPES_WITHOUT_TRUST_INFO == "true" ]]; then
    echo "setting Allow recipes to run without trust information"
    args+=("--fail")
fi
if [[ $JAMFUPLOAD_REPO == "true" ]]; then
    echo "setting Use jamf-upload repo (beta)"
    args+=("--jamf-uploader-repo")
fi

# now run
progress_dialog >/dev/null 2>&1
"$autopkgsetup" "${args[@]}"
echo "progress: complete" >> "$dialog_log"
echo "quit:" >> "$dialog_log" & sleep 0.1

# dialog when done
done_dialog

