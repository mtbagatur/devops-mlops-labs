# Usage: source env/use.sh   (sets KUBECONFIG for this lab in the current shell)
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
echo "KUBECONFIG=$KUBECONFIG (cluster $CLUSTER, namespace $NS)"
