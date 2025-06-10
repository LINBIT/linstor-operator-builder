#!/usr/bin/env python3
import argparse

import yaml


def run(raw_src):
    result = set()
    for doc in yaml.safe_load_all(raw_src):
        template_spec = doc.get("spec", {}).get("template", {}).get("spec", {})
        for container in template_spec.get("containers", []):
            result.add((container["name"], container["image"]))
        for initContainer in template_spec.get("initContainers", []):
            result.add((initContainer["name"], initContainer["image"]))

        for k, v in doc.get("data", {}).items():
            if k.endswith(".yaml"):
                image_config = yaml.safe_load(v)
                for name, component in image_config.get("components", {}).items():
                    result.add((name, f"{image_config['base']}/{component['image']}:{component['tag']}"))
                    for match in component.get("match", []):
                        result.add((name, f"{image_config['base']}/{match['image']}:{component['tag']}"))

    return result


def main():
    parser = argparse.ArgumentParser(description="extract image list from operator resources", exit_on_error=True)
    parser.add_argument("deployment", type=str)
    parser.add_argument("--print-component", action="store_true")
    args = parser.parse_args()

    with open(args.deployment, "rb") as src:
        result = run(src)

    if not args.print_component:
        for image in sorted(x[1] for x in result):
            print(image)
    else:
        for image in sorted(result, key=lambda x: x[0]):
            print(" ".join(image))


if __name__ == '__main__':
    main()
