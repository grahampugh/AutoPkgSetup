#!/usr/bin/python

"""
autopkg-jssimporter-setup.py

An idempotent script to automate setting up AutoPkg on a device.
"""


from install_command_line_tools import install_commandline_tools


def main():
    '''Do the main thing'''
    install_commandline_tools()


if __name__ == '__main__':
    main()
