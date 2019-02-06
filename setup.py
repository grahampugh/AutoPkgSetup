#!/usr/bin/python

"""
https://milkr.io/kfei/5-common-patterns-to-version-your-Python-package/5
"""

version = {}
with open("...autopkg_setup/version.py") as fp:
    exec(fp.read(), version)

# ...

setup(
	version = version['__version__']
)