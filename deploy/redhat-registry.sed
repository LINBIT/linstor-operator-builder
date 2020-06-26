s#"controllerImage": ".*"#"controllerImage": "registry.connect.redhat.com/linbit/linstor:latest"#g
s#"linstorPluginImage": ".*"#"linstorPluginImage": "registry.connect.redhat.com/linbit/linstor-csi:latest"#g
s#"kernelModImage": ".*"#"kernelModImage": "registry.connect.redhat.com/linbit/drbd-9:latest"#g
s#"satelliteImage": ".*"#"controllerImage": "registry.connect.redhat.com/linbit/drbd-9:latest"#g
s/drbdiocred//g
