#!/bin/sh -e

echo ' {{ if .Values.installCRDs }}'
find ./piraeus-operator/config/crd/bases -type f | sort | xargs --no-run-if-empty cat
echo '{{ end }}'
