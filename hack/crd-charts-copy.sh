#!/bin/sh -e

KUSTOMIZE="${KUSTOMIZE:-kustomize}"

echo '# DO NOT EDIT; Automatically created by hack/crd-charts-copy.sh'
echo '{{ if .Values.installCRDs }}'
echo '---'
$KUSTOMIZE build ./deploy/crd
echo '{{ end }}'
