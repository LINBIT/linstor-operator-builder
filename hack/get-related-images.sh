#!/usr/bin/bash
set -e

while read -r IMAGE; do
	REF="$(crane digest --full-ref $IMAGE)"
	NAME="${IMAGE##*/}"
	NAME="${NAME%%:*}"
	echo "- name: $NAME"
	echo "  image: $REF"
done
