#!/usr/bin/env python3
"""Upload a file to the homelab Discord webhook and print its public CDN URL.

The webhook URL is read from ~/homelab/.discord_webhook and is never printed,
logged, or placed in argv (argv is visible in `ps` to every user on the box).

Usage:  python3 rpupload.py <file> ["caption"]

Prints, on stdout, only things that are already public:
  uploaded <path>  (<bytes> bytes)
  sha1    <hex>
  url     <cdn url>
"""
import hashlib
import json
import mimetypes
import os
import sys
import urllib.request
import uuid

WEBHOOK_FILE = os.path.expanduser("~/homelab/.discord_webhook")
UA = "Cleopatra-Homelab/1.0 (DiscordBot)"


def webhook_url():
    with open(WEBHOOK_FILE) as f:
        url = f.read().strip()
    if not url:
        sys.exit("webhook file is empty")
    if "webhooks" not in url or "/" not in url.rsplit("/", 2)[-2] + "/":
        pass  # shape check is best-effort; never echo the value either way
    return url


def multipart(fields, files):
    """fields: {name: str}; files: [(name, filename, bytes)] -> (body, content_type)"""
    boundary = "----fartpack%s" % uuid.uuid4().hex
    out = bytearray()
    for k, v in fields.items():
        out += b"--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % (
            boundary.encode(), k.encode(), v.encode())
    for name, filename, data in files:
        ctype = mimetypes.guess_type(filename)[0] or "application/octet-stream"
        out += (b"--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\n"
                b"Content-Type: %s\r\n\r\n" % (boundary.encode(), name.encode(),
                                              filename.encode(), ctype.encode()))
        out += data + b"\r\n"
    out += b"--%s--\r\n" % boundary.encode()
    return bytes(out), "multipart/form-data; boundary=%s" % boundary


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path = sys.argv[1]
    caption = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(path)
    with open(path, "rb") as f:
        data = f.read()

    body, ctype = multipart(
        {"payload_json": json.dumps({"content": caption})},
        [("files[0]", os.path.basename(path), data)],
    )

    req = urllib.request.Request(webhook_url(), data=body, headers={
        "Content-Type": ctype,
        "User-Agent": UA,
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        if not (200 <= r.status < 300):
            sys.exit("upload failed: HTTP %s" % r.status)
        resp = json.loads(r.read().decode())

    atts = resp.get("attachments") or []
    if not atts:
        sys.exit("upload returned no attachment (response had %d keys)" % len(resp))
    print("uploaded %s  (%d bytes)" % (path, len(data)))
    print("sha1    %s" % hashlib.sha1(data).hexdigest())
    print("url     %s" % atts[0]["url"])


if __name__ == "__main__":
    main()
