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
COPY build/_output/bin/linstor-operator ${OPERATOR}

COPY build/bin /usr/local/bin
RUN  /usr/local/bin/user_setup

ENTRYPOINT ["/usr/local/bin/entrypoint"]

USER ${USER_UID}
