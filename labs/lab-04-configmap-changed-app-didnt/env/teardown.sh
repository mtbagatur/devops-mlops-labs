#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
kind delete cluster --name "$CLUSTER" --kubeconfig "$KUBECONFIG"
rm -f "$(dirname "${BASH_SOURCE[0]}")/lab.kubeconfig"
