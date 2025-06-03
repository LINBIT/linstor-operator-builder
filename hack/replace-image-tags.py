#!/usr/bin/python3
import sys

import yaml


def run(digests_for_image):
    docs = list(yaml.safe_load_all(sys.stdin))
    for doc in docs:
        template_spec = doc.get("spec", {}).get("template", {}).get("spec", {})
        for container in template_spec.get("containers", []):
            name = container["image"].split(":")[0]
            container["image"] = f"{name}@{digests_for_image[name]}"
        for initContainer in template_spec.get("initContainers", []):
            name = initContainer["image"].split(":")[0]
            initContainer["image"] = f"{name}@{digests_for_image[name]}"

        for k, v in doc.get("data", {}).items():
            if k.endswith(".yaml"):
                image_config = yaml.safe_load(v)
                for component in image_config.get("components", {}).values():
                    name = f"{image_config['base']}/{component['image']}"
                    component["digest"] = digests_for_image[name]
                    for match in component.get("match", []):
                        name = f"{image_config['base']}/{match['image']}"
                        match["digest"] = digests_for_image[name]
                doc["data"][k] = yaml.safe_dump(image_config)

    yaml.safe_dump_all(docs, sys.stdout)


def main():
    with open(sys.argv[1], "rb") as related_images_file:
        related_images = yaml.safe_load(related_images_file)

    digests_for_image = {}
    for entry in related_images:
        repo, digest = entry["image"].split("@")
        digests_for_image[repo] = digest

    run(digests_for_image)


if __name__ == '__main__':
    main()
