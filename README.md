# AutoPkg Setup for JSS

A script to automatically install [AutoPkg] and optionally configure [JamfUploader] for immediate use.

## What does it do?

* Installs command line tools if not present (because `git` is required for
    AutoPkg)
* Downloads, installs and configures the latest version of AutoPkg
* Optionally configures JamfUploader

The script is idempotent. It is safe to run if the Xcode Command Line Tools and
AutoPkgare already installed. They will only be updated if
they are out of date. Any existing AutoPkg repos will also be updated, with the
caveat that all the repos you want should be in your autopkg-repo-list file.

## Prerequisites for JamfUploader to work

Create a user on each JSS Instance with the following credentials
(**System Settings** => **JSS User Accounts & Groups**):  

* **Account:**
  * Username: `AutoPkg`
  * Access Level: `Full Access`
  * Privilege Set: `Custom`
  * Access Status: `Enabled`
  * Full Name: `AutoPkg JSSImporter`
  * Email Address: `jamfadmin@myorg.com`
  * Password: `ChangeMe!!!`  
* **Privileges:**
  * Categories: `Create` `Read` `Update`
  * Computer Extension Attributes: `Create` `Read` `Update`
  * File Share Distribution Points: `Read`
  * Packages: `Create` `Read` `Update`
  * Policies: `Create` `Read` `Update`
  * Scripts: `Create` `Read` `Update`
  * Smart Computer Groups: `Create` `Read` `Update`
  * Static Computer Groups: `Create` `Read` `Update`

You also need to know the password that the JSS uses to connect to the
distribution point.

## Download

Since one of the steps of this script is to install git, you'll perhaps not be able to git clone this script. So download the ZIP archive from the GitHub page, or use the following command to obtain the latest commit:

```
curl -L "https://github.com/grahampugh/AutoPkg_Setup_for_JSS/archive/refs/heads/main.zip" -o ~/Downloads/autopkg-setup.zip
```

Then unzip the downloaded zip file:

```
unzip ~/Downloads/autopkg-setup.zip
```

## Setup

Either add your required credentials into the AutoPkg prefs directly, or
the script will prompt you for them when you run it.

### Cloud distribution point

    # JSS address, API user and password
    JSS_URL="https://changeme.jamfcloud.com"
    JSS_API_AUTOPKG_USER="AutoPkg"
    JSS_API_AUTOPKG_PW="ChangeMe!!!"

### Fileshare distribution point

    # JSS address, API user and password
    JSS_URL="https://changeme.com:8443/"
    JSS_API_AUTOPKG_USER="AutoPkg"
    JSS_API_AUTOPKG_PW="ChangeMe!!!"

    # Jamf Distribution Server name and password. In normal usage, this is sufficient
    # due to information gathered from the JSS.
    JAMFREPO_NAME="CasperShare"
    JAMFREPO_PW="ChangeMeToo!!!"

Note that any paths in a config file should be absolute.

## Running the script

Run the script as the regular user (not as root/sudo).

Run with no options to: 

* Install the Xcode Command Line Tools
* Download and install AutoPkg
* Create the prefs file in the default location (`~/Library/Preferences/com.github.autopkg.plist`)
* Add the `grahampugh-recipes` repo

```
./autopkg-setup.sh
```
Additional options are as follows.

### Force reinstallation of AutoPkg

If you want to force the reinstallation of AutoPkg, for example to upgrade AutoPkg, use the `-f` or `--force` option.

### Allow recipes to run without trust

If you want to allow recipes to run without failing due to no trust, use the `-x` or `--fail` option.

### Install the latest pre-release version of AutoPkg

If you want to force the installation of the latest pre-release version of AutoPkg, use the `-b` or `--beta` option.

### Supply an existing prefs file

To supply an pre-made prefs file, use the `--prefs` option and specify a path, e.g. `./autopkg-setup.sh --prefs /path/to/com.myorg.autopkg.prefs`.

### Replace an existing prefs file

To delete any existing prefs file and start fresh, add the `--replace-prefs` option.

### Add a GitHub token

To add a GitHub token to aid with AutoPkg searches, add the `--github-token` option and specify the token, e.g. `./autopkg-setup.sh --github-token MY_GITHUB_TOKEN`.

### Add repos from a repo list

To add (or update) repos from a repo-list, add the `--repo-list` option and specify the path to the list, e.g. `./autopkg-setup.sh --repo-list /path/to/repolist.txt`.

### Add necessary repos for a recipe list

To ensure all dependencies for your recipe list are added to your repo list, add the `--recipe-list` option and specify the path to the list, e.g. `./autopkg-setup.sh --recipe-list /path/to/recipelist.txt`. This will run `autopkg info -p` for all recipes in the list and attempt to add all parent repos that are not already added. Note that this option is currently fragile due to problems with GitHub searches.


### Add a private repo to the AutoPkg search list

To add a private repo, supply the path to the repo with `--private-repo /path/to/private-repo` and the URL of the repo with `--private-repo-url https://my.git.server/reponame`.

## Configure JamfUploader

To configure JamfUploader, supply the Jamf Pro server URL, e.g. `--jss-url "https://my.jamfcloud.com"`.

You can supply the API user from the command line with the `--jss-user MY_USERNAME` option. If you use the `--jss-url` option but do not supply a value for `--jss-user`, and it is not already set in the AutoPkg prefs, you will be asked to supply it.

You can supply the API user's password from the command line with the `--jss-pass MY_PASSWORD` option. If you do not supply this value and it is not already set in the AutoPkg prefs, you will be asked to supply it.

Jamf Cloud Distribution Point users do not need to supply any additional keys.

To set `jcds_mode`, add the `-j` or `--jcds-mode` option.

If you have a local FileShare Distribution Point, supply the SMB server's full URL including Share name, e.g. `--smb-url "smb://my.jamf-dp.com/ShareName"`. The share must be a top level share.

You can supply the SMB user from the command line with the `--smb-user MY_SMB_USERNAME` option. If you use the `--smb-url` option but do not supply a value for `--smb-user`, and it is not already set in the AutoPkg prefs, you will be asked to supply it.

You can supply the API user's password from the command line with the `--smb-pass MY_SMB_PASSWORD` option. If you do not supply this value and it is not already set in the AutoPkg prefs, you will be asked to supply it.

## Configure a Slack webhook

To configure a Slack webhook, supply the hook with `--slack-webhook https://my.slack.webhook/url`. 

To set a username that Slack will report as, supply it with `--slack-user SLACK_USERNAME`.

[AutoPkg]: https://github.com/autopkg/autopkg
[JamfUploader]: https://github.com/grahampugh/jamf-upload/wiki/JamfUploader-AutoPkg-Processors
