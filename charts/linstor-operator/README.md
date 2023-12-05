# LINSTOR® Operator

Deploys the [LINSTOR Operator](https://charts.linstor.io/) which deploys and manages a simple
and resilient storage solution for Kubernetes.

This chart **only** configures the Operator, but does not create the `LinstorCluster` resource creating the actual
storage system. Refer to the existing [User Guide](https://linbit.com/drbd-user-guide/linstor-guide-1_0-en/#s-kubernetes-deploy-linbit-sds-for-k8s-operator-v2)
or use the `linbit-sds` chart.

## Deploying LINSTOR Operator

To deploy LINSTOR Operator with helm, add the repository to your helm configuration:

```
$ helm repo add linstor https://charts.linstor.io
$ helm repo update 
```

Then, deploy the `linstor-operator` chart, using your LINBIT credentials:

```
$ helm install linstor-operator linstor/linstor-operator --set imageCredentials.username=MY_LINBIT_USER --set imageCredentials.password=MY_LINBIT_PASSWORD
```

Once done, create your LINBIT SDS deployment using the `linbit-sds` chart:

```
$ helm install linbit-sds linstor/linbit-sds
```
