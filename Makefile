KUSTOMIZE ?= kustomize
OPERATOR_SDK ?= operator-sdk

VERSION := $(shell hack/semver.py)

CHANNELS ?= dev


.PHONY: out/static-deployment.yaml
out/static-deployment.yaml:
	mkdir -p out
	$(KUSTOMIZE) build ./deploy/default > out/static-deployment.yaml

out/image.list: out/static-deployment.yaml
	hack/get-image-list.py out/static-deployment.yaml > out/image.list

.PHONY: deploy/manifests/related-images.yaml
deploy/manifests/related-images.yaml: out/image.list
	hack/get-related-images.sh < $^ > $@

.PHONY: bundle
bundle: deploy/manifests/related-images.yaml
	rm -rf bundle
	$(KUSTOMIZE) build deploy/manifests --load-restrictor LoadRestrictionsNone \
	  | hack/replace-image-tags.py deploy/manifests/related-images.yaml \
	  | $(OPERATOR_SDK) generate bundle --channels $(CHANNELS) -q --overwrite --version $(VERSION)
	# Add related images information
	yq -ie '.spec.relatedImages = load("deploy/manifests/related-images.yaml")' bundle/manifests/linstor-operator.clusterserviceversion.yaml
	# These should really exist automatically, but don't. https://github.com/operator-framework/operator-sdk/pull/5560
	yq -ie '.annotations["com.redhat.openshift.versions"] = load("bundle/manifests/linstor-operator.clusterserviceversion.yaml").metadata.annotations["com.redhat.openshift.versions"]' bundle/metadata/annotations.yaml
	yq -ie '.metadata.annotations["containerImage"] = (load("deploy/manifests/related-images.yaml") | filter(.name == "linstor-operator")[0].image)' bundle/manifests/linstor-operator.clusterserviceversion.yaml
