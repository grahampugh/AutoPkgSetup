AutoPkg Setup for JSS
=====================

An automated installer for [AutoPkg] and [JSSImporter].


## What does it do?

* Installs command line tools if not present (because `git` is required for AutoPkg)
* Downloads, installs and configures the latest version of AutoPkg
* Uses AutoPkg to install JSSImporter
* Configures JSSImporter

The scripts are idempotent. It is safe to run if the Xcode Command Line Tools, AutoPkg and/or JSSImporter
are already installed. They will be updated if they are out of date. Any existing AutoPkg repos will also be updated.


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

You also need to know the password that the JSS uses to connect to the distribution point.


## Usage (python package)

1. Clone the repository to your local drive.
2. Copy `credentials_template.yaml` to `credentials.yaml` and fill in your JSS credentials.
3. Ensure the python modules `requests` and `pyyaml` are installed.
4. Run the script as a regular user (not root/sudo). 
   You will be asked to provide your administrator password to install AutoPkg.
    ```bash
    python ./autopkg_setup_for_jss.py
    ```


## Usage (bash script)

1. Edit and save the following variables in `autopkg_setup_for_jss.sh`:

    ```bash
    # JSS address, API user and password
    JSS_URL="https://changeme.com:8443/"
    JSS_API_AUTOPKG_USER="AutoPkg"
    JSS_API_AUTOPKG_PW="ChangeMe!!!"
    
    # Jamf Distribution Server name and password. In normal usage, this is sufficient
    # due to information gathered from the JSS.
    JAMFREPO_NAME="CasperShare"
    JAMFREPO_PW="ChangeMeToo!!!"
    ```

2. Run the script as the regular user (not as root/sudo):

    ```bash
    bash ./autopkg_setup_for_jss.sh
    ```


[AutoPkg]: https://github.com/autopkg/autopkg
[JSSImporter]: https://github.com/sheagcraig/JSSImporter
