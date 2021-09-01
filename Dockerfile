FROM --platform=$BUILDPLATFORM golang:1.17 as builder
ARG TARGETARCH

WORKDIR /workspace
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

COPY cmd/ cmd/
COPY pkg/ pkg/
COPY version/ version/

RUN GOARCH=$TARGETARCH CGO_ENABLED=0 go build --ldflags '-extldflags "-static"' -gcflags all=-trimpath=. --asmflags all=-trimpath=. -tags custom -o linstor-operator ./cmd/manager/main.go

FROM --platform=$TARGETPLATFORM registry.access.redhat.com/ubi8/ubi-minimal:latest

LABEL name="LINSTOR Operator" \
      vendor="LINBIT" \
      summary="LINSTOR Kubernetes Operator" \
      description="LINSTOR Kubernetes Operator"
COPY LICENSE /licenses/apache-2.0.txt

# install operator binary
COPY --from=builder /workspace/linstor-operator /linstor-operator

USER nobody
ENTRYPOINT ["/linstor-operator"]
