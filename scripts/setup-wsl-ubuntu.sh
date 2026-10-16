#!/usr/bin/env bash
# Installs the lab toolchain on Ubuntu (WSL2 or bare metal): Docker Engine, kubectl, kind, helm, jq.
# Safe to re-run. Asks for your sudo password; never pass it on the command line.
set -euo pipefail

KIND_VERSION="v0.33.0"
HELM_VERSION="v4.3.0"
ARCH="$(dpkg --print-architecture)"   # amd64 / arm64

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

step "Base packages"
sudo apt-get update -qq
sudo apt-get install -y -qq ca-certificates curl gnupg jq bash-completion

step "Docker Engine (official apt repository)"
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

step "kubectl (latest stable, checksum verified)"
K8S="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
tmp="$(mktemp -d)"
curl -fsSLo "$tmp/kubectl" "https://dl.k8s.io/release/${K8S}/bin/linux/${ARCH}/kubectl"
curl -fsSLo "$tmp/kubectl.sha256" "https://dl.k8s.io/release/${K8S}/bin/linux/${ARCH}/kubectl.sha256"
echo "$(cat "$tmp/kubectl.sha256")  $tmp/kubectl" | sha256sum --check --quiet
sudo install -m 0755 "$tmp/kubectl" /usr/local/bin/kubectl

step "kind ${KIND_VERSION}"
curl -fsSLo "$tmp/kind" "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
sudo install -m 0755 "$tmp/kind" /usr/local/bin/kind

step "helm ${HELM_VERSION}"
curl -fsSLo "$tmp/helm.tgz" "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"
tar -xzf "$tmp/helm.tgz" -C "$tmp"
sudo install -m 0755 "$tmp/linux-${ARCH}/helm" /usr/local/bin/helm
rm -rf "$tmp"

step "Shell completion"
grep -q 'kubectl completion bash' ~/.bashrc || cat >> ~/.bashrc <<'EOF'

# lab toolchain
source <(kubectl completion bash)
source <(helm completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
EOF

step "Versions"
docker --version
kubectl version --client | head -1
kind version
helm version --short

cat <<'EOF'

Done. Open a NEW Ubuntu terminal (or run `newgrp docker`) so your user can run docker without sudo, then:
  docker run --rm hello-world
EOF
