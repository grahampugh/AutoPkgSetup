#!/usr/bin/python

"""
An idempotent script to install the current Xcode command line tools.
"""

import platform
import subprocess
import os


def install_commandline_tools():
    """installs the Xcode Command Line Tools so that git is installed"""
    os_version = platform.mac_ver()[0]
    if int(os_version.split('.')[1]) < 9:
        done(1, "Sorry, this script is only for use on OS X/macOS >= 10.9")

    # touch the file that macOS needs to initiate install
    commandline_tools_temp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch(commandline_tools_temp_file)

    # grab the list of available software updates
    list_output = subprocess.Popen(["/usr/sbin/softwareupdate", "-l", "--product-types", "Command Line Tools"],
                                   stdout=subprocess.PIPE).communicate()[0]
    cli_version = ''
    for line in list_output.splitlines():
        if "* Command Line Tools" in line:
            cli_version = line.split(None, 1)[1]
    if cli_version:
        print "Found: {}".format(cli_version)

        # see if this was already installed
        found = False
        cli_compare = cli_version.replace("-", " ")
        history_output = subprocess.Popen(["/usr/sbin/softwareupdate", "-i", cli_version, "--history"],
                                          stdout=subprocess.PIPE).communicate()[0]
        for line in history_output.splitlines():
            if cli_compare in line:
                found = True
        if found:
            print "Command Line Tools already installed"
        else:
            # install the update
            print "Installing: {}".format(cli_version)
            install_output = subprocess.Popen(["/usr/sbin/softwareupdate", "-i", cli_version, "--verbose"],
                                              stdout=subprocess.PIPE).communicate()[0]
            print install_output

    # remove the touched file
    try:
        os.remove(commandline_tools_temp_file)
    except:
        pass



def touch(fname):
    """https://stackoverflow.com/questions/1158076/implement-touch-using-python"""
    try:
        os.utime(fname, None)
    except OSError:
        open(fname, 'a').close()


def done(exit_code, msg):
    """exit gracefully"""
    print msg
    exit(exit_code)


def main():
    """Do the main thing"""
    install_commandline_tools()


if __name__ == '__main__':
    main()
