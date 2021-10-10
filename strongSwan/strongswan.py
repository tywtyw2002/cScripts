import gzip
import ssl
import json as json_lib
import argparse
import sys
import os

from pathlib import Path
from getpass import getpass
from subprocess import call

from base64 import b64encode
from collections import namedtuple

from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, build_opener, HTTPRedirectHandler, HTTPSHandler

Response = namedtuple(
    'Response', 'request content json status url headers')


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


# copy from https://github.com/sesh/thttp/blob/main/thttp.py
def request(
    url,
    params={},
    json=None,
    data=None,
    headers={},
    method='GET',
    verify=True,
    redirect=True,
    basic_auth=None
):
    """
    Returns a (named)tuple with the following properties:
        - request
        - content
        - json (dict; or None)
        - headers (dict; all lowercase keys)
            - https://stackoverflow.com/questions/5258977/are-http-headers-case-sensitive
        - status
        - url (final url, after any redirects)
    """
    method = method.upper()
    headers = {k.lower(): v for k, v in headers.items()}  # lowecase headers
    headers['user-agent'] = headers.get('user-agent', "curl/7.64.1")

    if params:
        url += '?' + urlencode(params)  # build URL from params
    if json and data:
        raise Exception('Cannot provide both json and data parameters')
    if method not in ['POST', 'PATCH', 'PUT'] and (json or data):
        raise Exception(
            'Request method must POST, PATCH or PUT if json or data is provided')

    if json:  # if we have json, stringify and put it in our data variable
        headers['content-type'] = 'application/json'
        data = json_lib.dumps(json).encode('utf-8')
    elif data:
        data = urlencode(data).encode()

    if basic_auth and len(basic_auth) == 2 and 'authorization' not in headers:
        username, password = basic_auth
        headers['authorization'] = f'Basic {b64encode(f"{username}:{password}".encode()).decode("ascii")}'

    ctx = ssl.create_default_context()
    if not verify:  # ignore ssl errors
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    handlers = []
    handlers.append(HTTPSHandler(context=ctx))

    if not redirect:
        no_redirect = NoRedirect()
        handlers.append(no_redirect)

    opener = build_opener(*handlers)
    req = Request(url, data=data, headers=headers, method=method)

    try:
        with opener.open(req) as resp:
            status, content, resp_url = (
                resp.getcode(), resp.read(), resp.geturl())
            headers = {k.lower(): v for k, v in list(resp.info().items())}

            if 'gzip' in headers.get('content-encoding', ''):
                content = gzip.decompress(content)

            json = json_lib.loads(
                content) if 'application/json' in headers.get('content-type', '').lower() else None
    except HTTPError as e:
        status, content, resp_url = (e.code, e.read(), e.geturl())
        headers = {k.lower(): v for k, v in list(e.headers.items())}

        if 'gzip' in headers.get('content-encoding', ''):
            content = gzip.decompress(content)

        json = json_lib.loads(content) if 'application/json' in headers.get('content-type', '').lower() else None

    return Response(req, content, json, status, resp_url, headers)


def download_file(url, path):
    req = request(url)
    path.write_bytes(req.content)


def print_info(msg):
    print(f"[\033[32mINFO\033[0m] {msg}")


def print_error(msg):
    print(f"[\033[31mERROR\033[0m] {msg}")


# Start Script
GH_BASE_ROOT = "https://raw.githubusercontent.com/tywtyw2002/cScripts/master/strongSwan"
API_URL = "https://cpkg.c70.dev/pkg"


def download_version57(pkgs, deb_path):
    deb_url = "http://ftp.us.debian.org/debian/pool/main/i/iptables"
    extra_deb = ["libip4tc0_1.8.2-4_amd64.deb", "libip6tc0_1.8.2-4_amd64.deb"]

    for pkg in pkgs:
        if pkg["type"] != "file":
            continue
        download_file(pkg["download_url"], deb_path.joinpath(pkg['name']))

    # download extra
    for file in extra_deb:
        download_file(f"{deb_url}/{file}", deb_path.joinpath(file))


def download_version59(pkgs, deb_path):
    for pkg in pkgs:
        if pkg["type"] != "file":
            continue
        download_file(pkg["download_url"], deb_path.joinpath(pkg.name))


def parser_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--code', default=None, nargs="?")
    parser.add_argument('--v59', default=False, action='store_true')

    return parser.parse_args()


def main():
    root = Path(os.path.abspath(__file__)).parent

    args = parser_args()
    code = args.code
    pkg_name = "SWAN59" if args.v59 else "SWAN57"

    print_info(f"Install Version: {pkg_name}")

    if code is None:
        code = getpass("Please entry Passcode: ").strip()
        if not code:
            print_error("Error: Passcode cannot empty.")
            sys.exit(-1)

    # Requests api
    print_info("Request data from cpkg API...")
    api = request(f"{API_URL}/{pkg_name}", headers={'x-code': code})

    if api.status != 200:
        print_error(f"API Error. (Status: {api.status})")
        sys.exit(-2)

    deb_path = root.joinpath('deb')
    deb_path.mkdir(exist_ok=True)

    print_info("Download strongSwan Pkgs...")
    if args.v59:
        download_version59(api.json, deb_path)
    else:
        download_version57(api.json, deb_path)

    print_info("Install strongSwan...")
    # install debs
    call(["bash", "-c", "dpkg -i *.deb"], cwd=deb_path)


if __name__ == '__main__':
    main()