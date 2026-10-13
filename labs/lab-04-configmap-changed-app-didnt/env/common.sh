# Shared settings for lab 04. Sourced by setup.sh, teardown.sh, verify.sh and use.sh.
CLUSTER=lab-04
NS=shop
RELEASE=order-api

_env_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$_env_dir")"

# Native Windows tools (kind.exe, kubectl.exe, helm.exe) need C:/... paths when run from Git Bash.
native_path() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else echo "$1"; fi; }

CHART="$(native_path "$LAB_DIR/chart/order-api")"
# A dedicated kubeconfig keeps this lab away from any other cluster in ~/.kube/config.
export KUBECONFIG="$(native_path "$_env_dir/lab.kubeconfig")"
