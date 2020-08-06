#!/usr/bin/env sh
set -e

if [ -z "${1}" ] || [ -z "${2}" ] ; then
    echo "Usage: $0 <yaml-deployment-file> <csv-to-update>" >&2
    exit 1
fi

YAML_DEPLOYMENT_FILE="${1}"
CSV_FILE="${2}"

CSV_CONTENT="$(yq read --tojson --doc "*" "${YAML_DEPLOYMENT_FILE}")"

# Get all service accounts
SERVICE_ACCOUNTS="$(echo "${CSV_CONTENT}" | jq -r 'select(.kind=="ServiceAccount") | .metadata.name')"

PERMISSIONS="$(mktemp)"
# trap 'rm -rf "${PERMISSIONS}"' EXIT
CLUSTER_PERMISSIONS="$(mktemp)"
# trap 'rm -rf "${CLUSTER_PERMISSIONS}"' EXIT

# prepare files to be merged with actual values
echo "[]" > "${PERMISSIONS}"
echo "[]" > "${CLUSTER_PERMISSIONS}"

for SA in ${SERVICE_ACCOUNTS} ; do
  # Get all (cluster) role bindings for service account
  ROLE_BINDINGS="$(echo "${CSV_CONTENT}" | jq -r "select(.kind==\"RoleBinding\" and .subjects[].name==\"${SA}\") | .roleRef.name")"
  CLUSTER_ROLE_BINDINGS=$(echo "${CSV_CONTENT}" | jq -r "select(.kind==\"ClusterRoleBinding\" and .subjects[].name==\"${SA}\")  | .roleRef.name")

  for RB in ${ROLE_BINDINGS} ; do
    # Get referenced rules from role binding
    echo "${CSV_CONTENT}" \
      | jq "select(.kind==\"Role\" and .metadata.name==\"${RB}\") | .rules" \
      | jq "[{\"rules\": . , \"serviceAccountName\": \"${SA}\"}]" \
      | yq merge --inplace --append "${PERMISSIONS}" -
  done
  for CRB in ${CLUSTER_ROLE_BINDINGS} ; do
    # Get referenced rules from cluster role binding
    echo "${CSV_CONTENT}" \
      | jq "select(.kind==\"ClusterRole\" and .metadata.name==\"${CRB}\") | .rules" \
      | jq "[{\"rules\": . , \"serviceAccountName\": \"${SA}\"}]" \
      | yq merge --inplace --append "${CLUSTER_PERMISSIONS}" -
  done
done

yq write --inplace "${CSV_FILE}" spec.install.spec.clusterPermissions --from "${CLUSTER_PERMISSIONS}"
yq write --inplace "${CSV_FILE}" spec.install.spec.permissions --from "${PERMISSIONS}"
