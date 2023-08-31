# LINBIT SDS on K8s

See [the users guide](https://linbit.com/drbd-user-guide/linstor-guide-1_0-en/#s-kubernetes-deploy-linstor-operator-v2)

To deploy LINBIT SDS, you need to: 
* Have a working Kubernetes Cluster
* `kubectl` configured to point at the Cluster
* Your customer credentials for [my.linbit.com](https://my.linbit.com)

1. Create a `kustomization.yaml` file with the following content. Replace `MY_LINBIT_USER` and `MY_LINBIT_PASSWORD` with
   your own credentials.
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   namespace: linbit-sds
   resources:
     - https://charts.linstor.io/static/v2.2.0.yaml
   generatorOptions:
     disableNameSuffixHash: true
   secretGenerator:
     - name: drbdio-pull-secret
       type: kubernetes.io/dockerconfigjson
       literals:
         - .dockerconfigjson={"auths":{"drbd.io":{"username":"MY_LINBIT_USER","password":"MY_LINBIT_PASSWORD"}}}
   ```
2. Apply the kustomization.yaml file, by using kubectl command, and wait for the Operator to start:
   ```
   $ kubectl apply -k .
   namespace/linbit-sds created
   ...
   $ kubectl -n linbit-sds  wait pod --for=condition=Ready --all
   pod/linstor-operator-controller-manager-6d9847d857-zc985 condition met
   ```
3. Create a `LinstorCluster` resource to deploy the fill LINBIT SDS stack:
   ```
   $ kubectl create -f - <<EOF
   apiVersion: piraeus.io/v1
   kind: LinstorCluster
   metadata:
     name: linstorcluster
   spec: {}
   EOF
   $ kubectl wait pod --for=condition=Ready -n linbit-sds --timeout=3m --all
   pod/ha-controller-4tgcg condition met
   pod/k8s-1-26-10.test condition met
   pod/linstor-controller-76459dc6b6-tst8p condition met
   pod/linstor-csi-controller-75dfdc967d-dwdx6 condition met
   pod/linstor-csi-node-9gcwj condition met
   pod/linstor-operator-controller-manager-6d9847d857-zc985 condition met
   ```
