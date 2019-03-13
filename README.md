AutoPkg Setup for JSS
=====================

An automated installer for [AutoPkg] and [JSSImporter].


## What does it do?

* Installs command line tools if not present (because `git` is required for
    AutoPkg)
* Downloads, installs and configures the latest version of AutoPkg
* Uses AutoPkg to install JSSImporter
* Configures JSSImporter

The script is idempotent. It is safe to run if the Xcode Command Line Tools,
AutoPkg and/or JSSImporter are already installed. They will only be updated if
they are out of date. Any existing AutoPkg repos will also be updated.


### Prerequisites

Create a user on each JSS Instance with the following credentials
(**System Settings** => **JSS User Accounts & Groups**):  

* **Account:**
  - Username: `AutoPkg`
  - Access Level: `Full Access`
  - Privilege Set: `Custom`
  - Access Status: `Enabled`
  - Full Name: `AutoPkg JSSImporter`
  - Email Address: `jamfadmin@myorg.com`
  - Password: `ChangeMe!!!`  
* **Privileges:**
  - Categories: `Create` `Read` `Update`
  - Computer Extension Attributes: `Create` `Read` `Update`
  - File Share Distribution Points: `Read`
  - Packages: `Create` `Read` `Update`
  - Policies: `Create` `Read` `Update`
  - Scripts: `Create` `Read` `Update`
  - Smart Computer Groups: `Create` `Read` `Update`
  - Static Computer Groups: `Create` `Read` `Update`

You also need to know the password that the JSS uses to connect to the
distribution point.


## Usage

1. Either edit the variables in `autopkg_setup_for_jss.sh` directly, or make a
config file with the same content.

    For a cloud distribution point:

    ```bash
    # JSS address, API user and password
    JSS_URL="https://changeme.jamfcloud.com"
    JSS_API_AUTOPKG_USER="AutoPkg"
    JSS_API_AUTOPKG_PW="ChangeMe!!!"

    JSS_TYPE="Cloud"
    ```

    For a server distribution point:

    ```bash
    # JSS address, API user and password
    JSS_URL="https://changeme.com:8443/"
    JSS_API_AUTOPKG_USER="AutoPkg"
    JSS_API_AUTOPKG_PW="ChangeMe!!!"

    JSS_TYPE="DP"

    # Jamf Distribution Server name and password. In normal usage, this is sufficient
    # due to information gathered from the JSS.
    JAMFREPO_NAME="CasperShare"
    JAMFREPO_PW="ChangeMeToo!!!"
    ```

    For a local distribution point:

    ```bash
    # JSS address, API user and password
    JSS_URL="https://changeme.com:8443/"
    JSS_API_AUTOPKG_USER="AutoPkg"
    JSS_API_AUTOPKG_PW="ChangeMe!!!"

    JSS_TYPE="Local"

    # Jamf repo share name and mount point.
    JAMFREPO_NAME="CasperShare"
    JAMFREPO_MOUNTPOINT="/Volumes/CasperMountPoint"
    ```


2. Run the script as the regular user (not as root/sudo):

    If you edited `autopkg_setup_for_jss.sh` directly:

    ```bash
    ./autopkg_setup_for_jss.sh
    ```

    If supplying a config file:

    ```bash
    ./autopkg_setup_for_jss.sh /path/to/config_file.sh
    ```

    Note that any paths in a config file should preferably be absolute.
    

[AutoPkg]: https://github.com/autopkg/autopkg
[JSSImporter]: https://github.com/sheagcraig/JSSImporter
