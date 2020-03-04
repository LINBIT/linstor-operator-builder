SRCOP ?= piraeus-operator
SRCCHART ?= $(SRCOP)/charts/piraeus
DSTOP ?= linstor-operator
DSTCHART ?= linstor-operator-helm
IMAGE ?= drbd.io/$(notdir $(DSTOP))

DSTCHART := $(abspath $(DSTCHART))

all: operator chart

########## operator #########

SRC_FILES_LOCAL_CP = $(shell find build pkg -type f)
DST_FILES_LOCAL_CP = $(addprefix $(DSTOP)/,$(SRC_FILES_LOCAL_CP))

SRC_FILES_CP = $(shell find $(SRCOP)/cmd $(SRCOP)/pkg $(SRCOP)/version -type f)
SRC_FILES_CP += $(SRCOP)/build/bin/user_setup $(SRCOP)/go.mod $(SRCOP)/go.sum
DST_FILES_CP = $(subst $(SRCOP),$(DSTOP),$(SRC_FILES_CP))

operator: $(DST_FILES_LOCAL_CP) $(DST_FILES_CP)
	[ $$(basename $(DSTOP)) = "linstor-operator" ] || \
		(echo "error: last component of DSTOP must be linstor-operator" ; exit 1)
	cd $(DSTOP) && \
		operator-sdk build $(IMAGE) \
		--go-build-args "-tags custom"

$(DST_FILES_LOCAL_CP): $(DSTOP)/%: %
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

$(DST_FILES_CP): $(DSTOP)/%: $(SRCOP)/%
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

########## chart #########

CHART_SRC_FILES_LOCAL_CP = charts/linstor/values.yaml
CHART_DST_FILES_LOCAL_CP = $(subst charts/linstor,$(DSTCHART),$(CHART_SRC_FILES_LOCAL_CP))

CHART_SRC_FILES_REPLACE = $(shell find $(SRCCHART)/crds $(SRCCHART)/templates -type f)
CHART_SRC_FILES_REPLACE += $(SRCCHART)/Chart.yaml $(SRCCHART)/.helmignore
CHART_DST_FILES_REPLACE = $(subst $(SRCCHART),$(DSTCHART),$(CHART_SRC_FILES_REPLACE))

chart: $(CHART_DST_FILES_LOCAL_CP) $(CHART_DST_FILES_REPLACE)
	helm dependency update "$(DSTCHART)"

$(CHART_DST_FILES_LOCAL_CP): $(DSTCHART)/%: charts/linstor/%
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

$(CHART_DST_FILES_REPLACE): $(DSTCHART)/%: $(SRCCHART)/%
	mkdir -p "$$(dirname "$@")"
	< "$^" sed 's/piraeus/linstor/g ; s/Piraeus/Linstor/g' > "$@"

publish: chart
	tmpd=$$(mktemp -p $$PWD -d) && cd $$tmpd && \
	helm package $(DSTCHART) && helm repo index $$tmpd --url https://charts.linstor.io && \
	echo 'charts.linstor.io' > CNAME && \
	git init && git add . && git commit -m 'gh-pages' && \
	git push -f https://github.com/LINBIT/linstor-operator-builder.git master:gh-pages && \
	rm -rf $$tmpd

distclean:
	rm -rf "$(DSTOP)" "$(DSTCHART)"
