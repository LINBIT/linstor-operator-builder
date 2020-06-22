SRCOP ?= piraeus-operator
SRCCHART ?= $(SRCOP)/charts/piraeus
SRCPVCHART ?= $(SRCOP)/charts/pv-hostpath
DSTOP ?= linstor-operator
DSTCHART ?= linstor-operator-helm
DSTPVCHART ?= linstor-operator-helm-pv
DSTHELMPACKAGE ?= out/helm
REGISTRY ?= drbd.io
TAG ?= latest
UPSTREAMGIT ?= https://github.com/LINBIT/linstor-operator-builder.git

CHART_VERSION_ARGS := $(if $(CHART_VERSION),--version $(CHART_VERSION))
DSTCHART := $(abspath $(DSTCHART))
DSTPVCHART := $(abspath $(DSTPVCHART))
DSTHELMPACKAGE := $(abspath $(DSTHELMPACKAGE))
IMAGE := $(REGISTRY)/$(notdir $(DSTOP))

all: operator chart pvchart

distclean:
	rm -rf "$(DSTOP)" "$(DSTCHART)" "$(DSTPVCHART)" "$(DSTHELMPACKAGE)"

########## operator #########

SRC_FILES_LOCAL_CP = $(shell find LICENSE Dockerfile build pkg -type f)
DST_FILES_LOCAL_CP = $(addprefix $(DSTOP)/,$(SRC_FILES_LOCAL_CP))

SRC_FILES_CP = $(shell find $(SRCOP)/cmd $(SRCOP)/pkg $(SRCOP)/version -type f)
SRC_FILES_CP += $(SRCOP)/build/bin/user_setup $(SRCOP)/go.mod $(SRCOP)/go.sum
DST_FILES_CP = $(subst $(SRCOP),$(DSTOP),$(SRC_FILES_CP))

operator: $(DST_FILES_LOCAL_CP) $(DST_FILES_CP)
	[ $$(basename $(DSTOP)) = "linstor-operator" ] || \
		{ >&2 echo "error: last component of DSTOP must be linstor-operator"; exit 1; }
	cd $(DSTOP) && \
		docker build --tag $(IMAGE):$(TAG) .
	docker tag $(IMAGE):$(TAG) $(IMAGE):latest

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

CHART_SRC_FILES_REPLACE = $(shell find $(SRCCHART)/crds $(SRCCHART)/templates $(SRCCHART)/charts -type f)
CHART_SRC_FILES_REPLACE += $(SRCCHART)/.helmignore
CHART_DST_FILES_REPLACE = $(subst $(SRCCHART),$(DSTCHART),$(CHART_SRC_FILES_REPLACE))

chart: $(CHART_DST_FILES_MERGE) $(CHART_DST_FILES_REPLACE)
	helm package "$(DSTCHART)" --destination "$(DSTHELMPACKAGE)" $(CHART_VERSION_ARGS)

$(CHART_DST_FILES_MERGE): $(DSTCHART)/%: $(SRCCHART)/% charts/linstor/%
	mkdir -p "$$(dirname "$@")"
	yq merge --overwrite $^ | \
		sed 's/piraeus/linstor/g ; s/Piraeus/Linstor/g' > "$@"

$(CHART_DST_FILES_REPLACE): $(DSTCHART)/%: $(SRCCHART)/%
	mkdir -p "$$(dirname "$@")"
	sed 's/piraeus/linstor/g ; s/Piraeus/Linstor/g' "$^" > "$@"

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
