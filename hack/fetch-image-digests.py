#!/usr/bin/env python2
# Usage: hack/fetch-image-digests.py my-replacement-for-latest-tags
# Reads an array of {"env_name": ..., "pretty_name" ..., "image": ... } from stdin,
# replaces
from __future__ import print_function

import json
import sys
import subprocess

OUTPUT_FILE = sys.argv[1]
LATEST_REPLACEMENT = sys.argv[2]

work_items = json.load(sys.stdin)
output_items = []

for item in work_items:
    print("fetching manifest for '{}'".format(item["value"]), file=sys.stderr)
    repo, tag = item["value"].rsplit(":", 1)
    if tag == "latest":
        tag = LATEST_REPLACEMENT
    digest = subprocess.check_output(["crane", "digest", "{}:{}".format(repo, tag)]).strip().decode()
    item["value"] = "{}@{}".format(repo, digest)
    print("expanded to '{}'".format(item["value"]), file=sys.stderr)

with open(OUTPUT_FILE, "wb") as output:
    json.dump(work_items, output)
