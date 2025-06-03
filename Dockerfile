# syntax=docker/dockerfile:1
# Build the manager binary
FROM --platform=$BUILDPLATFORM golang:1 as builder

WORKDIR /workspace
# Copy the Go Modules manifests
COPY piraeus-operator/go.mod go.mod
COPY piraeus-operator/go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY piraeus-operator/cmd/ cmd/
COPY piraeus-operator/api/ api/
COPY piraeus-operator/internal/ internal/
COPY piraeus-operator/pkg/ pkg/
COPY override/pkg/vars/branding.go pkg/vars/branding.go

# Build
ARG TARGETARCH
ARG TARGETOS
ARG GOPROXY
ARG VERSION=0.0.0
RUN --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -ldflags "-X github.com/piraeusdatastore/piraeus-operator/v2/pkg/vars.Version=$VERSION" -o manager ./cmd
RUN --mount=type=cache,target=/root/.cache/go-build CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -a -ldflags "-X github.com/piraeusdatastore/piraeus-operator/v2/pkg/vars.Version=$VERSION" -o gencert ./cmd/gencert

# Use minimal base image to package the manager binary
FROM registry.access.redhat.com/ubi9/ubi-micro:latest

COPY LICENSE /licenses/Apache-2.0.txt

COPY --from=builder /workspace/manager /workspace/gencert /
USER 65534:65534

LABEL name="linstor-operator"
LABEL maintainer="LINBIT HA Solutions GmbH"
LABEL vendor="LINBIT HA Solutions GmbH"
ARG VERSION
LABEL version="$VERSION"
LABEL release=1
LABEL summary="Operator that deploys and maintains LINBIT SDS"
LABEL description="LINBIT SDS combines LINSTOR and DRBD open source software to provide high availability, scalability, and storage cluster management."

ENTRYPOINT ["/manager"]
