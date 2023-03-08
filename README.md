# LINBIT SDS on K8s

### Warning: Operator v2 is still in development

To deploy LINBIT SDS, you need to: 
* Have a working Kubernetes Cluster
* `kubectl` configured to point at the Cluster
* [cert-manager.io](https://cert-manager.io) deployed in your cluster
* Your customer credentials for [my.linbit.com](https://my.linbit.com)

```
$ kubectl create namespace linbit-sds
$ kubectl create secret -n linbit-sds docker-registry drbdio-pull-secret --docker-server=drbd.io --docker-username=$LINBIT_USERNAME --docker-password=$LINBIT_PASSWORD
$ kubectl apply -k "https://github.com/LINBIT/linstor-operator-builder//deploy/default?ref=v2.0.1"
$ kubectl apply -k "https://github.com/LINBIT/linstor-operator-builder//config/default?ref=v2.0.1"
```
