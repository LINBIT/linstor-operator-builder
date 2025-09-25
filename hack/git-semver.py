#!/usr/bin/env python3
import re
import subprocess
import sys

out = subprocess.check_output(["git", "describe", "--tags", "--always", "--dirty", "--long", "--match", "v*"], universal_newlines=True).strip()

match = re.match(r"^v([0-9]+)\.([0-9]+)\.([0-9]+)-([0-9]+)-g([0-9a-f]+)(-dirty)?$", out)
if not match:
    sys.exit(1)

major, minor, patch, extra, commit, dirty = match.groups()
if extra == b'0' and not dirty:
    print(f"{major}.{minor}.{patch}")
elif not dirty:
    print(f"{major}.{minor}.{int(patch)+1}-{extra}.g{commit}")
else:
    print(f"{major}.{minor}.{int(patch)+1}-{extra}.g{commit}.dirty")
