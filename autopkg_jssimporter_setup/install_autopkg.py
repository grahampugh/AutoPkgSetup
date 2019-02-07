#!/usr/bin/python

"""
install_autopkg.py

Downloads and installs AutoPkg.
"""

import requests
import subprocess


def get_download_url(url):
    '''get download URL from releases page'''
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
    '''get it'''
    r = requests.get(url)
    if r.status_code != 200:
        raise ValueError(
            'Request returned an error %s, the response is:\n%s'
            % (r.status_code, r.text)
        )
    with open(download_path, 'wb') as f:
        f.write(r.content)


def install_autopkg():
    '''install it'''
    url = 'https://api.github.com/repos/autopkg/autopkg/releases'
    download_path = '/tmp/autopkg-latest.pkg'

    # grab the download url
    url = get_download_url(url)

    # do the download
    download(url, download_path)

    # do the install
    output = subprocess.Popen(["/usr/sbin/installer", "-pkg", download_path, "-target", "/"],
                     stdout=subprocess.PIPE).communicate()[0]

    # remove the downloaded pkg
    try:
        os.remove(download_path)
    except:
        pass

    print output


def main():
    '''do the main thing'''
    install_autopkg()


if __name__ == '__main__':
    main()


