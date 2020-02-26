SRCOP ?= piraeus-operator
DSTOP ?= linstor-operator
IMAGE ?= drbd.io/$(notdir $(DSTOP))

SRC_FILES = $(shell find $(SRCOP)/cmd $(SRCOP)/pkg $(SRCOP)/version -type f)
SRC_FILES += $(SRCOP)/build/bin/user_setup $(SRCOP)/go.mod $(SRCOP)/go.sum
DST_FILES = $(subst $(SRCOP),$(DSTOP),$(SRC_FILES))


$(DSTOP)/%: $(SRCOP)/%
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

all: $(DST_FILES)
	rsync -av build $(DSTOP)
	cd $(DSTOP) && \
		operator-sdk build $(IMAGE) \
		--go-build-args "-ldflags -X=github.com/piraeusdatastore/piraeus-operator/pkg/k8s/spec.APIGroup=linstor.linbit.com"
