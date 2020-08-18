#!/usr/bin/env python3

import re
import subprocess
import sys

_GIT_DESCRIBE_PATTERN = re.compile(r"v(.*)-(\d+)-g([0-9a-f]{7,})")
_GIT_DESCRIBE_COMMAND = ["git", "describe", "--abbrev=40", "--long", "--tags", "--match", "v*.*"]

gitversion = subprocess.check_output(_GIT_DESCRIBE_COMMAND).decode().strip()

parsed = _GIT_DESCRIBE_PATTERN.fullmatch(gitversion)
if not parsed:
    print("'{}' not in expected format".format(gitversion), file=sys.stderr)
    sys.exit(1)

tag, changes, commit = parsed.groups()

if changes == "0":
    print(tag)
else:
    print("{}-dev{}+{}".format(tag, changes, commit))
