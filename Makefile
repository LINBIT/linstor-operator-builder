SRCNAME ?= piraeus
SRCOP ?= piraeus-operator
SRCCHART ?= $(SRCOP)/charts/piraeus
SRCPVCHART ?= $(SRCOP)/charts/pv-hostpath
DSTNAME ?= linstor
DSTOP ?= linstor-operator
DSTCHART ?= linstor-operator-helm
DSTPVCHART ?= linstor-operator-helm-pv
DSTHELMPACKAGE ?= out/helm
ARCH ?= $(shell go env GOARCH 2> /dev/null || echo amd64)
REGISTRY ?= drbd.io/$(ARCH)
SEMVER ?= $(shell hack/getsemver.py)
TAG ?= v$(subst +,-,$(SEMVER))
UPSTREAMGIT ?= https://github.com/LINBIT/linstor-operator-builder.git

DSTCHART := $(abspath $(DSTCHART))
DSTPVCHART := $(abspath $(DSTPVCHART))
DSTHELMPACKAGE := $(abspath $(DSTHELMPACKAGE))
IMAGE := $(REGISTRY)/$(notdir $(DSTOP))

all: operator chart pvchart olm

distclean:
	rm -rf "$(DSTOP)" "$(DSTCHART)" "$(DSTPVCHART)" "$(DSTHELMPACKAGE)"

########## operator #########

SRC_FILES_LOCAL_CP = $(shell find LICENSE Dockerfile build pkg -type f)
DST_FILES_LOCAL_CP = $(addprefix $(DSTOP)/,$(SRC_FILES_LOCAL_CP))

SRC_FILES_CP = $(shell find $(SRCOP)/cmd $(SRCOP)/pkg $(SRCOP)/version -type f)
SRC_FILES_CP += $(SRCOP)/build/bin/user_setup $(SRCOP)/go.mod $(SRCOP)/go.sum
DST_FILES_CP = $(subst $(SRCOP),$(DSTOP),$(SRC_FILES_CP))

operator: $(DSTOP)
	[ $$(basename $(DSTOP)) = "linstor-operator" ] || \
		{ >&2 echo "error: last component of DSTOP must be linstor-operator"; exit 1; }
	cd $(DSTOP) && \
		docker build --tag $(IMAGE):$(TAG) .
	docker tag $(IMAGE):$(TAG) $(IMAGE):latest

$(DSTOP): $(DST_FILES_LOCAL_CP) $(DST_FILES_CP)

$(DST_FILES_LOCAL_CP): $(DSTOP)/%: %
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

$(DST_FILES_CP): $(DSTOP)/%: $(SRCOP)/%
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

########## chart #########

CHART_LOCAL = charts/linstor
CHART_SRC_FILES_MERGE = $(CHART_LOCAL)/Chart.yaml $(CHART_LOCAL)/values.yaml
CHART_DST_FILES_MERGE = $(subst $(CHART_LOCAL),$(DSTCHART),$(CHART_SRC_FILES_MERGE))

CHART_SRC_FILES_REPLACE = $(shell find $(SRCCHART)/templates $(SRCCHART)/charts -type f)
CHART_SRC_FILES_REPLACE += $(SRCCHART)/.helmignore
CHART_DST_FILES_REPLACE = $(subst $(SRCCHART),$(DSTCHART),$(CHART_SRC_FILES_REPLACE))

CHART_SRC_FILES_RENAME = $(shell find $(SRCCHART)/crds -type f)
CHART_DST_FILES_RENAME_TMP = $(subst $(SRCCHART),$(DSTCHART),$(CHART_SRC_FILES_RENAME))
CHART_DST_FILES_RENAME = $(subst $(SRCNAME),$(DSTNAME),$(CHART_DST_FILES_RENAME_TMP))

chart: $(DSTCHART)
	helm package "$(DSTCHART)" --destination "$(DSTHELMPACKAGE)" --version $(SEMVER)

$(DSTCHART): $(CHART_DST_FILES_MERGE) $(CHART_DST_FILES_REPLACE) $(CHART_DST_FILES_RENAME)

$(CHART_DST_FILES_MERGE): $(DSTCHART)/%: $(SRCCHART)/% charts/linstor/%
	mkdir -p "$$(dirname "$@")"
	yq merge --overwrite $^ | \
		sed 's/piraeus/linstor/g ; s/Piraeus/Linstor/g' > "$@"

$(CHART_DST_FILES_REPLACE): $(DSTCHART)/%: $(SRCCHART)/%
	mkdir -p "$$(dirname "$@")"
	sed 's/piraeus/linstor/g ; s/Piraeus/Linstor/g' "$^" > "$@"

$(CHART_DST_FILES_RENAME): $(DSTCHART)/crds/$(DSTNAME).linbit.%: $(SRCCHART)/crds/$(SRCNAME).linbit.%
	mkdir -p "$$(dirname "$@")"
	sed 's/piraeus/linstor/g ; s/Piraeus/Linstor/g' "$^" > "$@"

########## OLM bundle ##########
olm: $(DSTOP)/deploy/crds $(DSTOP)/deploy/operator.yaml
	# Needed for operator-sdk to choose the correct project version
	mkdir -p $(DSTOP)/build
	touch -a $(DSTOP)/build/Dockerfile
	# The relevant roles are already part of operator.yaml, as created by helm. operator-sdk still requires this file to work
	touch -a $(DSTOP)/deploy/role.yaml

	cd $(DSTOP) ; operator-sdk generate csv --csv-version $(SEMVER) --update-crds
	# Fix CSV permissions
	hack/patch-csv-rules.sh $(DSTOP)/deploy/operator.yaml $(DSTOP)/deploy/olm-catalog/$(DSTOP)/$(SEMVER)/*clusterserviceversion.yaml
	# Fill CSV with project values
	yq -P merge --inplace --overwrite $(DSTOP)/deploy/olm-catalog/$(DSTOP)/$(SEMVER)/*clusterserviceversion.yaml deploy/linstor-operator.clusterserviceversion.part.yaml
	# Set CSV version
	yq -P write --inplace $(DSTOP)/deploy/olm-catalog/$(DSTOP)/$(SEMVER)/$(DSTOP).*.clusterserviceversion.yaml 'spec.version' $(SEMVER)
	# Remove imagePullSecrets (not needed, controlled via OLM mechanism)
	yq -P delete --inplace $(DSTOP)/deploy/olm-catalog/$(DSTOP)/$(SEMVER)/$(DSTOP).*.clusterserviceversion.yaml 'spec.install.spec.deployments[*].spec.template.spec.imagePullSecrets'
	# Remove the "replaces" section, its not guaranteed to always find the real latest version
	yq -P delete --inplace $(DSTOP)/deploy/olm-catalog/$(DSTOP)/$(SEMVER)/$(DSTOP).*.clusterserviceversion.yaml 'spec.replaces'
	# Replace the referenced images with ones for OLM
	sed -rf hack/redhat-registry.sed -i $(DSTOP)/deploy/olm-catalog/$(DSTOP)/$(SEMVER)/*clusterserviceversion.yaml

	# Update package yaml, setting the current version to be the latest
	yq -P write --inplace $(DSTOP)/deploy/olm-catalog/$(DSTOP)/$(DSTOP).package.yaml 'channels[0].currentCSV' $(DSTOP).v$(SEMVER)

	# Copy to output directory
	mkdir -p out/olm/$(SEMVER)
	cp -av -t out/olm/$(SEMVER) $(DSTOP)/deploy/olm-catalog/$(DSTOP)/*.yaml $(DSTOP)/deploy/olm-catalog/$(DSTOP)/$(SEMVER)/*.yaml

	# create zip package
	python -m zipfile --create out/olm/$(SEMVER).zip out/olm/$(SEMVER)/*

$(DSTOP)/deploy/operator.yaml: $(DSTCHART) deploy/linstor-operator-csv.helm-values.yaml
	mkdir -p "$$(dirname "$@")"
	helm template linstor $(DSTCHART) -f deploy/linstor-operator-csv.helm-values.yaml > "$@"

$(DSTOP)/deploy/crds: $(DSTCHART)
	mkdir -p "$@"
	cp -av -t $(DSTOP)/deploy/ $(DSTCHART)/crds

########## chart for hostPath PersistentVolume #########

PVCHART_SRC_FILES_CP = $(shell find $(SRCPVCHART) -type f)
PVCHART_DST_FILES_CP = $(subst $(SRCPVCHART),$(DSTPVCHART),$(PVCHART_SRC_FILES_CP))

pvchart: $(PVCHART_DST_FILES_CP)
	helm package --destination "$(DSTHELMPACKAGE)" "$(DSTPVCHART)"

$(PVCHART_DST_FILES_CP): $(DSTPVCHART)/%: $(SRCPVCHART)/%
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

########## publishing #########

publish: chart pvchart
	tmpd=$$(mktemp -p $$PWD -d) && pw=$$PWD && churl=https://charts.linstor.io && \
	chmod 775 $$tmpd && cd $$tmpd && \
	git clone -b gh-pages --single-branch $(UPSTREAMGIT) . && \
	cp $$pw/index.template.html ./index.html && \
	cp "$(DSTHELMPACKAGE)"/* . && \
	helm repo index . --url $$churl && \
	for f in $$(ls -v *.tgz); do echo "<li><p><a href='$$churl/$$f' title='$$churl/$$f'>$$(basename $$f)</a></p></li>" >> index.html; done && \
	echo '</ul></section></body></html>' >> index.html && \
	git add . && git commit -am 'gh-pages' && \
	git push $(UPSTREAMGIT) gh-pages:gh-pages && \
	rm -rf $$tmpd

upload: operator
	docker push $(IMAGE):$(TAG)
	docker push $(IMAGE):latest

.PHONY:	publish upload pvchart olm chart operator $(DSTOP) $(DSTCHART)
