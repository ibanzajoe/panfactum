#!/usr/bin/env bash

set -eo pipefail

####################################################################
# Step 1: Variable parsing
####################################################################

# Initialize our own variables:
NAMESPACE=
WINDOW_ID=

# Define the function to display the usage
usage() {
  echo "Disables disruptions for PDBs configured to allow time windows for disruptions."
  echo "Usage: pf-voluntary-disruptions-disable --namespace=<namespace> --window-id=<window-id>" >&2
  echo "       pf-voluntary-disruptions-disable -n=<namespace> -w=<window-id>" >&2
  echo "" >&2
  echo "<namespace>:        Namespace of the PDBs" >&2
  echo "<window-id>:        ID of the disruption window" >&2
  echo "" >&2
  exit 1
}

# Parse command line arguments
TEMP=$(getopt -o n:w: --long namespace:,window-id: -- "$@")

# shellcheck disable=SC2181
if [[ $? != 0 ]]; then
  echo "Failed parsing options." >&2
  exit 1
fi

# Note the quotes around `$TEMP`: they are essential!
eval set -- "$TEMP"

# Extract options and their arguments into variables
while true; do
  case "$1" in
  -n | --namespace)
    NAMESPACE="$2"
    shift 2
    ;;
  -w | --window-id)
    WINDOW_ID="$2"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  *)
    usage
    ;;
  esac
done

if [[ -z $NAMESPACE ]]; then
  echo "--namespace must be set" >&2
  exit 1
fi

if [[ -z $WINDOW_ID ]]; then
  echo "--window-id must be set" >&2
  exit 1
fi

####################################################################
# Step 2: Disable disruptions on the PDBs for the given disruption window ID
####################################################################

for PDB in $(kubectl get pdb -n argo -l "panfactum.com/voluntary-disruption-window=$WINDOW_ID" --ignore-not-found -o name); do
  ANNOTATIONS=$(kubectl get "$PDB" -n "$NAMESPACE" -o jsonpath="{.metadata.annotations}")
  START_TIME=$(echo "$ANNOTATIONS" | jq -r '.["panfactum.com/voluntary-disruption-window-start"]')
  if [[ $START_TIME == "null" ]]; then
    echo "'$PDB' in namespace '$NAMESPACE' does not have 'panfactum.com/voluntary-disruption-window-start' annotation. Skipping." >&2
  elif [[ $((START_TIME + 3600)) -ge $(date +%s) ]]; then
    echo "'$PDB' in namespace '$NAMESPACE' started disruption window in the last hour. Skipping." >&2
  else
    echo "Updating '$PDB' in namespace '$NAMESPACE' with maxUnavailable=0" >&2
    kubectl patch "$PDB" -n "$NAMESPACE" --type='json' -p="[{\"op\": \"replace\", \"path\": \"/spec/maxUnavailable\", \"value\": 0}]" >/dev/null
    kubectl annotate "$PDB" -n "$NAMESPACE" "panfactum.com/voluntary-disruption-window-start-" --overwrite >/dev/null
  fi
done