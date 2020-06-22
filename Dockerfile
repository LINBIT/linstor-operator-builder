FROM golang:1.13 as builder

WORKDIR /workspace
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

COPY cmd/ cmd/
COPY pkg/ pkg/
COPY version/ version/

RUN CGO_ENABLED=0 go build -tags custom -o linstor-operator ./cmd/manager/main.go


FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

ENV OPERATOR=/usr/local/bin/linstor-operator \
    USER_UID=1001 \
    USER_NAME=linstor-operator

LABEL name="LINSTOR Operator" \
      vendor="LINBIT" \
      summary="LINSTOR Kubernetes Operator" \
      description="LINSTOR Kubernetes Operator"
COPY LICENSE /licenses/apache-2.0.txt

# install operator binary
COPY --from=builder /workspace/linstor-operator ${OPERATOR}

COPY build/bin /usr/local/bin
RUN  /usr/local/bin/user_setup

ENTRYPOINT ["/usr/local/bin/entrypoint"]

USER ${USER_UID}
