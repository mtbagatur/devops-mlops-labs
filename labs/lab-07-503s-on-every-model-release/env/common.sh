# Shared settings for lab 07. Sourced by setup.sh, teardown.sh, traffic.sh, verify.sh and use.sh.
CLUSTER=lab-07
NS=support-ai
APP=llm-gateway

_env_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$_env_dir")"

# Native Windows tools (kind.exe, kubectl.exe) need C:/... paths when run from Git Bash.
native_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

MANIFESTS="$(native_path "$_env_dir/manifests")"
# A dedicated kubeconfig keeps this lab away from any other cluster in ~/.kube/config.
export KUBECONFIG="$(native_path "$_env_dir/lab.kubeconfig")"
