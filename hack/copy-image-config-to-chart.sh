#!/bin/sh
set -e

cat <<EOF
# DO NOT EDIT; Automatically created by hack/copy-image-config-to-chart.sh
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "linstor-operator.fullname" . }}-image-config
  labels:
  {{- include "linstor-operator.labels" . | nindent 4 }}
data:
  0_linbit_sds_images.yaml: |
EOF

sed 's/^/    /' deploy/operator/0_linbit_sds_images.yaml
cat <<EOF
  0_sig_storage_images.yaml: |
EOF
sed 's/^/    /' piraeus-operator/config/manager/0_sig_storage_images.yaml

cat <<EOF
  {{- range \$idx, \$value := .Values.imageConfigOverride }}
  {{ add \$idx 1 }}_helm_override.yaml: |
    {{- \$value | toYaml | nindent 4 }}
  {{- end }}
EOF
