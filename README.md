# Linstor Operator Builder

Linstor Operator Builder creates the Linstor Operator from the Piraeus
Operator. The Linstor Operator is available to
[LINBIT](https://www.linbit.com/) customers. Installation and usage is
documented [here](https://docs.linbit.com/docs/linstor-guide/#ch-kubernetes).

## Operator Image

The Linstor Operator Docker image can be built with:

```
make SRCOP=<PATH> IMAGE=<TAG> operator
```

## Helm Chart

The Linstor Operator can be deployed using a generated Helm chart.
The chart generation requires [`yq`](https://github.com/mikefarah/yq).
The chart can be built with:

```
make SRCOP=<PATH> chart pvchart
```

And published with:

```
make SRCOP=<PATH> UPSTREAMGIT=<URL> publish
```
