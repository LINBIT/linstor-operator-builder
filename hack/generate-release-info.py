#!/usr/bin/env python3
import json
import os
import pathlib
import sys

import semver
import yaml


def read_all_files(pattern):
    result = {}
    for entry in pattern:
        if os.path.islink(entry):
            continue

        with open(entry, "rb") as content:
            result[os.path.basename(entry)] = content.read()

    return result


def parse_static_manifest(raw_manifest):
    api_versions = set()
    parsed = list(yaml.safe_load_all(raw_manifest))
    for document in parsed:
        api_versions.add(document.get("apiVersion", "v1"))
    return {
        "apiVersions": sorted(api_versions),
    }


def get_static_version(name: str):
    return name.removesuffix(".yaml").removeprefix("v")


def collect_static_files(base: pathlib.Path):
    result = {}

    static_files = read_all_files(base.glob("*.yaml"))
    for name, manifest in static_files.items():
        version = get_static_version(name)
        parsed = parse_static_manifest(manifest)
        images = base.joinpath(f"v{version}.image-list").read_text().splitlines()
        result[name] = {
            "file": name,
            "version": version,
            "images": sorted(images),
            **parsed
        }

    return sorted(result.values(), key=lambda x: semver.VersionInfo.parse(x["version"]), reverse=True)


def main():
    result = collect_static_files(pathlib.Path(sys.argv[1]))

    json.dump(result, sys.stdout)


if __name__ == '__main__':
    main()
