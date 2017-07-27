AutoPkg_Setup_for_JSS
=====================

A single-script installer for [AutoPkg] and [JSSImporter].


## What does it do?

* Installs command line tools if not present (because `git` is required for AutoPkg)
* Downloads, installs and configures the latest version of AutoPkg
* Uses AutoPkg to install JSSImporter
* Configures JSSImporter

### Prerequisites

Create a user on each JSS Instance with the following credentials (**System Settings** => **JSS User Accounts & Groups**):  

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


## Usage

As a bare minimum, edit and save the following variables in `AutoPkg_Setup_for_JSS.sh`:

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

Then, run the script as the regular user (not as root/sudo):

```bash
./AutoPkg_Setup_for_JSS.sh
```

[AutoPkg]: https://github.com/autopkg/autopkg
[JSSImporter]: https://github.com/sheagcraig/JSSImporter
