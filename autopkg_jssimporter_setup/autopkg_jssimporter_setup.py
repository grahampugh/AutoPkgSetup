#!/usr/bin/python

"""
autopkg_jssimporter_setup.py

An idempotent script to automate setting up AutoPkg on a device.
"""


from install_commandline_tools import install_commandline_tools
from install_autopkg import install_autopkg


def main():
    '''Do the main thing'''
    install_commandline_tools()
    install_autopkg()


if __name__ == '__main__':
    main()
