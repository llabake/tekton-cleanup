#!/bin/bash

# Function to get the list of successful pipelineruns
get_successful_pipelineruns() {
  local namespace="$1"
  kubectl -n "$namespace" get pipelineruns.tekton.dev -o jsonpath='{range .items[?(@.status.conditions[*].status=="True"))]}{.metadata.name}{"\n"}{end}'
}

# Function to collect child resources for a given pipelinerun
collect_child_resources() {
  local namespace="$1"
  local pipelinerun="$2"
  kubectl -n "$namespace" get pipelineruns "$pipelinerun" -o json | jq -r "$1" | uniq
}

# Function to delete resources by type
delete_resources() {
  local namespace="$1"
  local resource_type="$2"
  shift  2
  local resources=("$@")

  if [[ ${#resources[@]} -gt  0 ]]; then
    kubectl -n "$namespace" delete "$resource_type" "${resources[@]}"
    echo "Deleted $resource_type: ${resources[*]}"
  else
    echo "No $resource_type to delete."
  fi
}

# Namespace for Tekton pipelines
namespace="tekton-pipelines"

# Retrieve successful pipelineruns
successful_pipelineruns=($(get_successful_pipelineruns "$namespace"))

# Loop through each successful pipelinerun
for pipelinerun in "${successful_pipelineruns[@]}"; do
  # Collect child resources
  taskruns=($(collect_child_resources "$namespace" "$pipelinerun" '.status.childReferences[].name'))
  tasks=($(collect_child_resources "$namespace" "$pipelinerun" '.status.childReferences[].pipelineTaskName | select(. != null)'))
  pipelines=($(collect_child_resources "$namespace" "$pipelinerun" '.spec.pipelineRef.name | select(. != null)'))
  secrets=($(collect_child_resources "$namespace" "$pipelinerun" '.spec.workspaces[].secret.secretName | select(. != null)'))
  podnames=($(collect_child_resources "$namespace" "$pipelinerun" '.status.childReferences[].name | map("\(.+"-pod)")'))
  volumeclaims=($(collect_child_resources "$namespace" "$pipelinerun" '.spec.workspaces[].persistentVolumeClaim.claimName | select(. != null)'))

  # Delete pods
  delete_resources "$namespace" pod "${podnames[@]}"

  # Delete taskruns
  delete_resources "$namespace" taskrun "${taskruns[@]}"

  # Delete pipelineruns
  delete_resources "$namespace" pipelineruns.tekton.dev "$pipelinerun"

  # Delete tasks
  delete_resources "$namespace" task "${tasks[@]}"

  # Delete pipelines
  delete_resources "$namespace" pipeline "${pipelines[@]}"

  # Delete volume claims
  delete_resources "$namespace" pvc "${volumeclaims[@]}"

  # Delete secrets
  delete_resources "$namespace" secret "${secrets[@]}"
done
