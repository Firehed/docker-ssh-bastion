# SSHD

This is a docker image that does nothing but run sshd.
It was created for the purposes of having an SSH bastion in Kubernetes for a MySQL client, but can fulfill any purpose (but if you are using it for pod administration, there is probably something else wrong).
As such, this readme focuses primarily on usage within a K8S installation.

## Configuration

### `authorized_keys`
The image should start without any configuration, but it will not be very useful.
At the very least, you will want to add your SSH public key to `authorized_keys`.
To do so, mount a volume to `/root/.ssh` containing an `authorized_keys` file.
It is recommended to put your keys in a `ConfigMap` or `Secret` and mount that in the pod.

### Host keys
When the image starts, it will generate any missing host keys.
This allows you to get up and running with minimal setup.
However, this means that any time the pod starts new keys will be generated, resulting in that scary message about keys changing.
To avoid this, you have three choices:

1. _RECOMMENDED_: Generate host keys once and mount them into the image
2. (not recommended) `UserKnownHostsFile /dev/null` in your `.ssh/config` or as a flag when connecting
3. (really not recommended) Delete the relevant line from your `.ssh/known_hosts` any time this happens

Option 1 is a bit more work, but a) still fairly easy and b) provides the best experience.
To do this, start by generating the host keys locally:

    ssh-keygen -f ssh_host_ecdsa_key -N '' -t ecdsa
    ssh-keygen -f ssh_host_ed25519_key -N '' -t ed25519
    ssh-keygen -f ssh_host_rsa_key -N '' -t rsa

Then create a `Secret` from them:

    kubectl create secret generic ssh-host-keys --from-file=ssh_host_ecdsa_key --from-file=ssh_host_ed25519_key --from-file=ssh_host_rsa_key

Finally, mount the secret as a volume in the pod to `/etc/ssh` (a complete example is below)

### `StrictModes no`
In my experience, Kubernetes likes creating the files from the ConfigMaps and Secrets with wide-open permissions (on the symlink it uses to mount them, if not also the underlying file).
SSHD, of course, does not like `0777` on files containing keys.
These two things directly conflict with each other, and as a result you won't be able to log in.
As a workaround, you can set a `STRICT_MODES` environment variable to `no`, and `StrictModes no` will be appended to the SSHD config file, preventing these checks.

## A complete example

This will create a new Service with a public IP address (since it has a `LoadBalancer` type), pointing to a configured Deployment of this image. You should ensure that the Service you create is given a static IP.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ssh-bastion
spec:
  ports:
    - port: 22
      name: ssh
  selector:
    app: ssh-bastion
  type: LoadBalancer
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: ssh-bastion
spec:
  template:
    metadata:
      labels:
        app: ssh-bastion
    spec:
      containers:
        - image: firehed/sshd
          name: sshd
          ports:
            - containerPort: 22
              name: ssh
          env:
            - name: STRICT_MODES
              value: "no"
          volumeMounts:
            - mountPath: /root/.ssh
              name: public-keys
            - mountPath: /etc/ssh
              name: host-keys
      volumes:
        - name: public-keys
          configMap:
            name: ssh-public-keys
            defaultMode: 0400
        - name: host-keys
          secret:
            secretName: ssh-host-keys
            defaultMode: 0400
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssh-public-keys
data:
  authorized_keys: your public key (ssh-rsa 2IssTgUfjE0KKxu+kLBzxopZ6xs50zM1m8eoPsQ== keyname@example.com)
---
apiVersion: v1
kind: Secret
metadata:
  name: ssh-host-keys
data:
  ssh_host_ecdsa_key: (base64-encoded key)
  ssh_host_ed25519_key: (base64-encoded key)
  ssh_host_rsa_key: (base64-encoded key)
```
