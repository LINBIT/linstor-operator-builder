#!/usr/bin/env sh
set -e

if [ -z "${1}" ] || [ -z "${2}" ]; then
    echo "Usage: $0 <csv-to-update> <image-config>" >&2
    exit 1
fi

CSV_FILE="${1}"
IMAGE_CONFIG="${2}"

UPDATED_ENV="
$(yq read --prettyPrint "${CSV_FILE}" spec.install.spec.deployments[0].spec.template.spec.containers[0].env)
$(yq read --tojson "${IMAGE_CONFIG}" | yq read --prettyPrint -)
"
NEW_ENV_YAML="$(echo "$UPDATED_ENV" | yq prefix --prettyPrint - spec.install.spec.deployments[0].spec.template.spec.containers[0].env)"
echo "${NEW_ENV_YAML}" | yq merge --prettyPrint --inplace --overwrite "${CSV_FILE}" -

# set the deployment image for linstor-operator to the tagged version
OPERATOR_IMAGE="$(yq read --tojson  "${IMAGE_CONFIG}" | jq -r '.[] | select(.name=="RELATED_IMAGE_OPERATOR") | .value')"
yq write --prettyPrint --inplace "${CSV_FILE}" spec.install.spec.deployments[0].spec.template.spec.containers[0].image "${OPERATOR_IMAGE}"
