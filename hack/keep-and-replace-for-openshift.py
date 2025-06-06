#!/usr/bin/python3
import sys

import yaml


def run():
    docs = list(yaml.safe_load_all(sys.stdin))
    for doc in docs:
        for k, v in doc.get("data", {}).items():
            if k.endswith(".yaml"):
                image_config = yaml.safe_load(v)
                for component in image_config.get("components", {}).values():
                    if component['image'].startswith('drbd9-'):
                        component['image'] = 'drbd9-rhel9'  # Default to RHEL9 if no other distro could be determined
                    matches = component.get("match", [])
                    if matches:
                        component['match'] = [m for m in matches if m['image'].startswith('drbd9-rhel')]
                doc["data"][k] = yaml.safe_dump(image_config)

    yaml.safe_dump_all(docs, sys.stdout)


def main():
    run()


if __name__ == '__main__':
    main()
