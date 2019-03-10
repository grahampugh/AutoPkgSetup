#!/usr/bin/python

"""
install_autopkg.py

Downloads and installs AutoPkg.
"""

import os
import requests
import subprocess


def check_not_sudo():
    """this script must run as a regular user who will be called to supply their password"""
    uid = os.getuid()
    if uid == 0:
        print ("This script cannot be run as root!\n"
               "Please re-run the script as the regular user")
        exit(1)
    else:
        print ("This script requires administrator rights to install autopkg.\n"
               "Please enter your password if prompted")


def run_live(c):
    """Run a subprocess with real-time output.
    Returns only the return-code."""
    # Validate that command is not a string
    if isinstance(c, basestring): # Not an array!
        raise TypeError('Command must be an array')

    # Run the command
    proc = subprocess.Popen(c, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (c_out, c_err) = proc.communicate()
    if c_out:
        print "Result:\n%s" % c_out
    if c_err:
        print "Error:\n%s" % c_err


def get_download_url(url):
    """get download URL from releases page"""
    r = requests.get(url)
    if r.status_code != 200:
        raise ValueError(
            'Request returned an error %s, the response is:\n%s'
            % (r.status_code, r.text)
        )
    obj = r.json()
    browser_download_url = obj[0]["assets"][0]["browser_download_url"]
    return browser_download_url


def download(url, download_path):
    """get it"""
    r = requests.get(url)
    if r.status_code != 200:
        raise ValueError(
            'Request returned an error %s, the response is:\n%s'
            % (r.status_code, r.text)
        )
    with open(download_path, 'wb') as f:
        f.write(r.content)


def add_repo(repo):
    """Adds an AutoPkg recipe repo"""
    cmd = ['/usr/local/bin/autopkg', 'repo-add', repo]
    run_live(cmd)


def add_private_repo(repo):
    """Adds a private AutoPkg recipe repo"""
    cmd = ['/usr/local/bin/autopkg', 'repo-add', repo]
    run_live(cmd)


def update_repos():
    """Update any existing AutoPkg recipe repos"""
    cmd = ['/usr/local/bin/autopkg', 'repo-update', 'all']
    run_live(cmd)


def remove_download(download_path):
    """remove the downloaded pkg"""
    try:
        os.remove(download_path)
    except:
        pass


def install_autopkg():
    """install it"""
    url = 'https://api.github.com/repos/autopkg/autopkg/releases'
    download_path = '/tmp/autopkg-latest.pkg'

    # check script is not running as root
    check_not_sudo()

    # grab the download url
    url = get_download_url(url)

    # do the download
    download(url, download_path)

    # do the install
    cmd = ["/usr/bin/sudo", "/usr/sbin/installer", "-pkg", download_path, "-target", "/"]
    run_live(cmd)

    # remove download
    remove_download(download_path)

    # add repos if there is a list
    try:
        repos_file = os.path.join(os.getcwd(), "autopkg-repo-list.txt")
        with open(repos_file) as f:
            repos = f.readlines()
            repos = [x.strip() for x in repos] # strips newline characters
    except UnboundLocalError:
        print "No repo file"

    # add repos from autopkg-repo-list.txt
    for repo in repos:
        add_repo(repo)

    # update repos (this duplication is for repos that were already present)


def main():
    """do the main thing"""
    install_autopkg()





if __name__ == '__main__':
    main()
