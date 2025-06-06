KUSTOMIZE ?= kustomize
OPERATOR_SDK ?= operator-sdk

VERSION ?= $(shell hack/semver.py)
UPSTREAM_REF ?= v$(VERSION)

CHANNELS ?= dev


.PHONY: out/static-deployment.yaml
out/static-deployment.yaml:
	mkdir -p out
	$(KUSTOMIZE) build ./deploy/default > out/static-deployment.yaml

out/image.list: out/static-deployment.yaml
	hack/get-image-list.py out/static-deployment.yaml > out/image.list

.PHONY: deploy/manifests/related-images.yaml
deploy/manifests/related-images.yaml:
	$(KUSTOMIZE) build deploy/manifests --load-restrictor LoadRestrictionsNone \
	  | hack/keep-and-replace-for-openshift.py \
	  | hack/get-image-list.py /dev/stdin \
	  | hack/get-related-images.sh > $@

.PHONY: bundle
bundle: deploy/manifests/related-images.yaml
	rm -rf bundle
	$(KUSTOMIZE) build deploy/manifests --load-restrictor LoadRestrictionsNone \
	  | hack/keep-and-replace-for-openshift.py \
	  | hack/replace-image-tags.py deploy/manifests/related-images.yaml \
	  | $(OPERATOR_SDK) generate bundle --channels $(CHANNELS) -q --overwrite --version $(VERSION)
	# Add related images information
	yq -ie '.spec.relatedImages = load("deploy/manifests/related-images.yaml")' bundle/manifests/linstor-operator.clusterserviceversion.yaml
	# These should really exist automatically, but don't. https://github.com/operator-framework/operator-sdk/pull/5560
	yq -ie '.annotations["com.redhat.openshift.versions"] = load("bundle/manifests/linstor-operator.clusterserviceversion.yaml").metadata.annotations["com.redhat.openshift.versions"]' bundle/metadata/annotations.yaml
	yq -ie '.metadata.annotations["containerImage"] = (load("deploy/manifests/related-images.yaml") | filter(.name == "linstor-operator")[0].image)' bundle/manifests/linstor-operator.clusterserviceversion.yaml

.PHONY: release
release:
	git -C piraeus-operator fetch && git -C piraeus-operator checkout $(UPSTREAM_REF)
	hack/copy-image-config-to-chart.sh > charts/linstor-operator/templates/config.yaml
	hack/crd-charts-copy.sh > charts/linstor-operator/templates/crds.yaml
	yq -ie '.version = "$(VERSION)" | .appVersion = "v$(VERSION)"' charts/linstor-operator/Chart.yaml
	cd deploy/default && $(KUSTOMIZE) edit set image controller=drbd.io/linstor-operator:v$(VERSION)
	cd deploy/manifests/operator && $(KUSTOMIZE) edit set image controller=drbd.io/linstor-operator:v$(VERSION)
	git add piraeus-operator charts/linstor-operator/templates/config.yaml charts/linstor-operator/templates/crds.yaml charts/linstor-operator/Chart.yaml deploy/default/kustomization.yaml deploy/manifests/operator/kustomization.yaml
	git diff --staged
	@echo git commit -svm "Release $(VERSION)"
	@echo git tag -sm "Release $(VERSION)" v$(VERSION)
