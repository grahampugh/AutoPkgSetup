#!/usr/bin/python

"""
autopkg_setup_for_jss

This package consists of three modules:
1. Installs the Xcode command line tools
2. Installs AutoPkg and the 'recipes' repo, and updates any already-installed repos
3. Installs and configures JSSImporter using AutoPkg

Each could be run independently, if the requirements of the previous modules are already satisfied

Requirements:

The following python modules are required, which will need to be installed using pip
- requests
- pyyaml
"""

import sys
import autopkg_jssimporter_setup


autopkg_prefs_file = sys.argv[1]

autopkg_jssimporter_setup.main(autopkg_prefs_file)
