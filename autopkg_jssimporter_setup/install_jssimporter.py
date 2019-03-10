#!/usr/bin/python

"""
install_jssimporter.py

Downloads and installs JSS Importer.
For now we use the AuoPkg recipe.

Elements of this script from:
https://github.com/facebook/IT-CPE/blob/master/autopkg_tools/autopkg_tools.py
"""

import os
import subprocess
import json
import yaml as pyyaml
from plistlib import writePlistToString
from install_autopkg import run_live
from install_autopkg import download


def read_plist(plist):
    """Converts binary plist to json and then imports the content as a dict"""
    content = plist.read()
    args = ["plutil", "-convert", "json", "-o", "-", "--", "-"]
    proc = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    out, err = proc.communicate(content)
    return json.loads(out)


def convert_to_plist(yaml):
    """Converts dict to plist format"""
    lines = writePlistToString(yaml).splitlines()
    lines.append('')
    return "\n".join(lines)


def repo_add(repo):
    """Adds an AutoPkg recipe repo"""
    cmd = ['/usr/local/bin/autopkg', 'repo-add', repo]
    run_live(cmd)


def make_override(recipe):
    """Makes an override for a recipe"""
    cmd = ['/usr/local/bin/autopkg', 'make-override', recipe]
    run_live(cmd)


def run_recipe(recipe, report_plist_path=None, pkg_path=None):
    """
    Executes autopkg on a recipe, creating report plist.
    Taken from https://github.com/facebook/IT-CPE/blob/master/autopkg_tools/autopkg_tools.py
    """
    cmd = ['/usr/local/bin/autopkg', 'run', '-v']
    cmd.append(recipe)
    if pkg_path:
        cmd.append('-p')
        cmd.append(pkg_path)
    if report_plist_path:
        cmd.append('--report-plist')
        cmd.append(report_plist_path)
    run_live(cmd)


def install_jssimporter(autopkg_prefs_file=None):
    """Installs JSSImporter using AutoPkg"""
    # install JSSImporter
    repo_add('grahampugh/recipes')
    make_override('JSSImporterBeta.install')
    run_recipe('JSSImporterBeta.install')

    # temporarily get latest version directly from GitHub
    jssimporterpy_beta_url = 'https://raw.githubusercontent.com/grahampugh/JSSImporter/testing/JSSImporter.py'
    tmp_location = '/tmp/JSSImporter.py'
    jssimporterpy_location = '/Library/AutoPkg/autopkglib/JSSImporter.py'
    download(jssimporterpy_beta_url, tmp_location)
    cmd = ["/usr/bin/sudo", "mv", tmp_location, jssimporterpy_location]
    run_live(cmd)
    print "Installed latest JSSImporter"

    # grab data from any existing AutoPkg prefs file
    prefs = os.path.join(os.path.expanduser("~"), 'Library/Preferences/com.github.autopkg.plist')
    if os.path.isfile(prefs):
        prefs_file = open(prefs, 'r')
        prefs_data = read_plist(prefs_file)
        new_prefs = prefs_data.copy()
        prefs_file.close()
    else:
        print "No existing com.github.autopkg.plist"

    # grab credentials from yaml file
    try:
        autopkg_prefs_file = os.path.join(os.getcwd(), autopkg_prefs_file)
        print "Inputted prefs file: {}".format(autopkg_prefs_file)
    except UnboundLocalError:
        autopkg_prefs_file = os.path.join(os.getcwd(), "autopkg-preferences.yaml")
        print "Inputted prefs file: {}".format(autopkg_prefs_file)
    if os.path.isfile(autopkg_prefs_file):
        in_file = open(autopkg_prefs_file, 'r')
        input = pyyaml.safe_load(in_file)

        if new_prefs:
            new_prefs.update(input)
        else:
            new_prefs = input.copy()

        output = convert_to_plist(new_prefs)

        try:
            prefs_file = open(prefs, 'w')
            prefs_file.writelines(output)
            print "Updated JSSImporter configuration"
        except:
            print "AutoPkg preferences could not be created."
            exit(1)
    else:
        print "No autopkg_prefs_file found! Please create autopkg-preferences.yaml in the base of the repo."
        exit(1)


def main():
    """Does the main thing"""
    autopkg_prefs_file = os.path.join(os.pardir, "autopkg-preferences.yaml")
    install_jssimporter(autopkg_prefs_file)


if __name__ == '__main__':
    main()
