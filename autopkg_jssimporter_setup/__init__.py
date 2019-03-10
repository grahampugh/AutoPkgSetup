#!/usr/bin/python

"""
autopkg_jssimporter_setup.py

An idempotent script to automate setting up AutoPkg on a device.
"""


from autopkg_jssimporter_setup.install_commandline_tools import install_commandline_tools
from autopkg_jssimporter_setup.install_autopkg import install_autopkg
from autopkg_jssimporter_setup.install_jssimporter import install_jssimporter


def main(autopkg_prefs_file=None):
    """Do the main thing"""
    install_commandline_tools()
    install_autopkg()
    install_jssimporter(autopkg_prefs_file)


if __name__ == '__main__':
    main()
