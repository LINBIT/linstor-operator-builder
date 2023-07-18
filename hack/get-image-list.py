#!/usr/bin/env python3

import sys

import yaml


def run(raw_src):
    result = set()
    for doc in yaml.safe_load_all(raw_src):
        template_spec = doc.get("spec", {}).get("template", {}).get("spec", {})
        for container in template_spec.get("containers", []):
            result.add(container["image"])
        for initContainer in template_spec.get("initContainers", []):
            result.add(initContainer["image"])

        for k, v in doc.get("data", {}).items():
            if k.endswith(".yaml"):
                image_config = yaml.safe_load(v)
                for component in image_config.get("components", {}).values():
                    result.add(f"{image_config['base']}/{component['image']}:{component['tag']}")
                    for match in component.get("match", []):
                        result.add(f"{image_config['base']}/{match['image']}:{component['tag']}")

    return result


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <deployment-file>", file=sys.stderr)
        exit(1)

    with open(sys.argv[1], "rb") as src:
        result = run(src)

    for image in sorted(result):
        print(image)


if __name__ == '__main__':
    main()
