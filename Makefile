SRCOP ?= piraeus-operator
DSTOP ?= linstor-operator
IMAGE ?= drbd.io/$(notdir $(DSTOP))

SRC_FILES = $(shell find $(SRCOP)/cmd $(SRCOP)/pkg $(SRCOP)/version -type f)
SRC_FILES += $(DSTOP)/build/bin/user_setup $(DSTOP)/go.mod $(DSTOP)/go.sum
DST_FILES = $(subst $(SRCOP),$(DSTOP),$(SRC_FILES))


$(DSTOP)/%: $(SRCOP)/%
	mkdir -p "$$(dirname "$@")"
	cp -av "$^" "$@"

all: $(DST_FILES)
	rsync -av build $(DSTOP)
	cd $(DSTOP) && operator-sdk build $(IMAGE)
