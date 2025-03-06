#!/bin/sh
set -o errexit
set -x

#####
# forked from https://kind.sigs.k8s.io/docs/user/local-registry/
# modified to create cluster idempotently
#   + a workaround to ensure ~/.kube/config from post-create.sh
#   + a workaround to ignore validation errors when kube-apiserver is only partially ready

# 1. Create registry container unless it already exists
control_plane_name='kind-control-plane'
reg_name='kind-registry'
reg_port='5001'

if [ "$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --network bridge --name "${reg_name}" \
    registry:2
fi

# 2. Create kind cluster with containerd registry config dir enabled
# TODO: kind will eventually enable this by default and this patch will
# be unnecessary.
#
# See:
# https://github.com/kubernetes-sigs/kind/issues/2875
# https://github.com/containerd/containerd/blob/main/docs/cri/config.md#registry-configuration
# See: https://github.com/containerd/containerd/blob/main/docs/hosts.md
if [ "$(docker inspect -f '{{.State.Running}}' "${control_plane_name}" 2>/dev/null || true)" != 'true' ]; then

cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry]
    config_path = "/etc/containerd/certs.d"
nodes:
- role: control-plane
  image: kindest/node:v1.30.0
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
EOF

fi

# 2.5 [WORKAROUND] ensure the kube config exists
# for some reason, running kind create cluster from post-create.sh does not
# auto create and merge like normal
mkdir -p ~/.kube/
kind get kubeconfig > ~/.kube/config

# 3. Add the registry config to the nodes
#
# This is necessary because localhost resolves to loopback addresses that are
# network-namespace local.
# In other words: localhost in the container is not localhost on the host.
#
# We want a consistent name that works from both ends, so we tell containerd to
# alias localhost:${reg_port} to the registry container when pulling images
REGISTRY_DIR="/etc/containerd/certs.d/localhost:${reg_port}"
for node in $(kind get nodes); do
  docker exec "${node}" mkdir -p "${REGISTRY_DIR}"
  cat <<EOF | docker exec -i "${node}" cp /dev/stdin "${REGISTRY_DIR}/hosts.toml"
[host."http://${reg_name}:5000"]
EOF
done

# 4. Connect the registry to the cluster network if not already connected
# This allows kind to bootstrap the network but ensures they're on the same network
if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${reg_name}")" = 'null' ]; then
  docker network connect "kind" "${reg_name}"
fi

# 5. Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
#
# [WORKAROUND] `kubectl apply --validate=warn` more reliable when kube-apiserver
# has not had enough time prepare the openapi schema. A warning is still printed
# but requests can succceed, and we ignore the kubectl status code with bash.
cat <<EOF | kubectl apply --validate=warn -f - || echo "WORKAROUND: ignoring validation warning"
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo "[success] kind cluster and registry are running"
