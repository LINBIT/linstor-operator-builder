# Linstor Operator Builder

Linstor Operator Builder creates the Linstor Operator from the Piraeus
Operator. The Linstor Operator is available to
[LINBIT](https://www.linbit.com/) customers. Installation and usage is
documented [here](https://docs.linbit.com/docs/linstor-guide/#ch-kubernetes).

## Operator Image

The Linstor Operator Docker image can be built with:

```
make IMAGE=<TAG> operator
```

### Operator Versioning

The Linstor Operator version is currently exactly the same as the version of
the Piraeus Operator from which it was generated.

## Helm Chart

The Linstor Operator can be deployed using a generated Helm chart.
The chart generation requires [`yq`](https://github.com/mikefarah/yq).
The chart can be built with:

```
make chart pvchart
```

And published with:

```
make UPSTREAMGIT=<URL> publish
```

### Helm Chart Versioning

The Helm chart has its own version, independent of the Piraeus Operator Helm
chart.

# Build OLM Bundle

```
make BUILDENV=release olm
docker/podman build -t <bundle-name> --build-arg CHANNELS=alpha,stable out/olm-bundle/<version>
```
