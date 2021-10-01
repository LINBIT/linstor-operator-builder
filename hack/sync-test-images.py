#!/usr/bin/env python3
import subprocess
import sys

import yaml

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} <src-mapping> <dest-mapping>", file=sys.stderr)
    sys.exit(1)

with open(sys.argv[1]) as f:
    src = yaml.safe_load(f)

with open(sys.argv[2]) as f:
    dest = yaml.safe_load(f)

for item in src:
    matched = next(x for x in dest if x["name"] == item["name"])
    if not matched:
        print(f"{item['name']} in {sys.argv[1]}, but not in {sys.argv[2]}", file=sys.stderr)
        sys.exit(1)

    subprocess.run(["crane", "copy", item["value"], matched["value"]])
