#!/bin/bash
set -e

while read -r COMPONENT IMAGE; do
	REF="$(crane digest --full-ref "$IMAGE")"
	NAME="${IMAGE##*/}"
	NAME="${NAME%%:*}"
	if [ "${COMPONENT}" != "${NAME}" ]; then
		NAME="${COMPONENT}_${NAME}"
	fi
	echo "- name: ${NAME}"
	echo "  image: ${REF}"
done
