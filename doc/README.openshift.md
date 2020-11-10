LINSTOR is a configuration management system for storage on Linux systems.
It manages LVM logical volumes and/or ZFS ZVOLs on a cluster of nodes.
It leverages DRBD for replication between different nodes and to provide block
storage devices to users and applications. It manages snapshots, encryption and
caching of HDD backed data in SSDs via bcache.

LINBIT provides a certified LINSTOR operator to ease deployment of LINSTOR
on Openshift by installing DRBD, managing Satellite and Controller pods,
and integrating with Openshift to provision persistent storage for your workloads.

For detailed instructions and more configuration options, see our [user guide].

[user guide]: https://www.linbit.com/drbd-user-guide/linstor-guide-1_0-en/#ch-openshift

## Install

Unlike deployment via the helm chart, the certified Openshift
operator does not deploy the needed etcd cluster. You must deploy this
yourself ahead of time. We do this via the etcd operator available in the
OperatorHub.

IMPORTANT: It is advised that the etcd deployment uses persistent
storage of some type. Either use an existing storage provisioner with
a default `StorageClass` or simply use `hostPath` volumes.

### Installing the operator

Hit "Install", select the stable update channel and a namespace for the
operator. Use of a new namespace is recommended.

Hit "Install" again. At this point you should have just one pod, the
operator pod, running. Next we needs to configure the remaining provided APIs.

#### A note on operator namespaces
The LINSTOR operator can only watch for events and manage
custom resources that are within the same namespace it is deployed
within (OwnNamsespace). This means the LINSTOR Controller, LINSTOR
Satellites, and LINSTOR CSI Driver pods all need to be deployed in the
same namsepace as the LINSTOR Operator pod.

### Deploying the LINSTOR Controller

Navigate to the left-hand control pane of the Openshift Web
Console. Expand the "Operators" section, selecting "Installed Operators".
Find the entry for the "Linstor Operator", then select the "LinstorController"
from the "Provided APIs" column on the right.

From here you should see a page that says "No Operands Found" and will
feature a large button on the right which says "Create
LinstorController". Click the "Create LinstorController" button.

Here you will be presented with options to configure the LINSTOR
Controller. Either via the web-form view or the YAML View. Regardless
of which view you select, make sure that the `dbConnectionURL` matches
the endpoint provided from your etcd deployment. Otherwise, the
defaults are usually fine for most purposes.

Lastly hit "Create", you should now see a linstor-controller pod
running.

### Deploying the LINSTOR Satellites

Next we need to deploy the Satellites Set. Just as before navigate
to the left-hand control pane of the Openshift Web Console. Expand the
"Operators" section, but this time select "Installed Operators". Find
the entry for the "Linstor Operator", then select the
"LinstorSatelliteSet" from the "Provided APIs" column on the right.

From here you should see a page that says "No Operands Found" and will
feature a large button on the right which says "Create
LinstorSatelliteSet". Click the "Create LinstorSatelliteSet" button.

Here you will be presented with the options to configure the LINSTOR
Satellites. The defaults should be enough to get you started.
Make sure the `controllerEndpoint` matches what is available in the
openshift endpoints. The default is usually correct here.

You can edit the `storagePools` section to configure LINSTOR storage pools,
including preparing the backing devices. See our [storage guide].

[storage guide]: https://www.linbit.com/drbd-user-guide/linstor-guide-1_0-en/#s-kubernetes-storage

Below is an example manifest:

```yaml
apiVersion: linstor.linbit.com/v1
kind: LinstorSatelliteSet
metadata:
  name: linstor-satellites
spec:
  satelliteImage: ''
  automaticStorageType: None
  storagePools:
    lvmThinPools:
    - name: openshift-pool
      volumeGroup: ""
      thinVolume: openshift
      devicePaths:
      - /dev/vdb
  drbdRepoCred: ''
  kernelModuleInjectionMode: ShippedModules
  controllerEndpoint: 'http://linstor:3370'
  priorityClassName: ''
```

Lastly hit "Create", you should now see a linstor-node pod
running on every worker node.

### Deploying the LINSTOR CSI driver

Last bit left is the CSI pods to bridge the layer between the CSI and
LINSTOR. Just as before navigate to the left-hand control pane of the
Openshift Web Console. Expand the "Operators" section, but this time
select "Installed Operators". Find the entry for the "Linstor Operator",
then select the "LinstorCSIDriver" from the "Provided APIs" column on the
right.

From here you should see a page that says "No Operands Found" and will
feature a large button on the right which says "Create
LinstorCSIDriver". Click the "Create LinstorCSIDriver" button.

Again, you will be presented with the options. Make sure that the
`controllerEndpoint` is correct. Otherwise the defaults are fine for
most use cases.

Lastly hit "Create". You will now see a single "linstor-csi-controller" pod,
as well as a "linstor-csi-node" pod on all worker nodes.

## Interacting with LINSTOR in Openshift.

The Controller pod includes a LINSTOR Client, making it easy to interact directly with LINSTOR.
For instance:

```
oc exec deployment/linstor-cs-controller -- linstor storage-pool list
```

This should only be necessary for investigating problems and accessing advanced functionality.
Regular operation such as creating volumes should be achieved via the [Openshift/Kubernetes integration].

[Openshift/Kubernetes integration]: https://www.linbit.com/drbd-user-guide/linstor-guide-1_0-en/#s-kubernetes-basic-configuration-and-deployment
