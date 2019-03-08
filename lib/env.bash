#!/bin/bash

debug_mode='off'
if [[ "${BUILDKITE_PLUGIN_ANKA_DEBUG:-false}" =~ (true|on|1) ]] ; then
  echo ":hammer: Enabling debug mode"
  debug_mode='on'
fi

cleanup_mode='on'
if [[ "${BUILDKITE_PLUGIN_ANKA_CLEANUP:-true}" =~ (false|off|0) ]]; then
  if [[ debug_mode == 'on' ]]; then echo ":hammer: Disabling VM Clone Cleanup"; fi
  cleanup_mode='off'
fi

job_image_name="${BUILDKITE_PLUGIN_ANKA_VM_NAME}-${BUILDKITE_JOB_ID}"

#
# Decide whether we need to download the vm image from the registry
#   anka registry pull --help
#

if ( ! anka list "$BUILDKITE_PLUGIN_ANKA_VM_NAME" ) || [[ "${BUILDKITE_PLUGIN_ANKA_ALWAYS_PULL:-false}" =~ (true|on|1) ]]; then
  pull_args=()

  if [[ -n "${BUILDKITE_PLUGIN_ANKA_VM_REGISTRY_TAG:-}" ]]; then
    pull_args+=("--tag" "${BUILDKITE_PLUGIN_ANKA_VM_REGISTRY_TAG:-}")
  fi

  if [[ -n "${BUILDKITE_PLUGIN_ANKA_VM_REGISTRY_VERSION:-}" ]]; then
    pull_args+=("--version" "${BUILDKITE_PLUGIN_ANKA_VM_REGISTRY_VERSION:-}")
  fi

  echo "--- :anka: Pulling $BUILDKITE_PLUGIN_ANKA_VM_NAME from Anka Registry"

  if [[ "${debug_mode:-off}" =~ (on) ]] ; then
    echo "$ anka registry pull ${pull_args[*]} $BUILDKITE_PLUGIN_ANKA_VM_NAME" >&2
  fi

  eval "anka registry pull ${pull_args[*]} $BUILDKITE_PLUGIN_ANKA_VM_NAME"
else
  echo ":anka: $BUILDKITE_PLUGIN_ANKA_VM_NAME is already present on the host"
fi

#
# Parse out all the run command options
#   anka run --help
#

args=()

# Working directory inside the VM
if [[ -n "${BUILDKITE_PLUGIN_ANKA_WORKDIR:-}" ]] ; then
  args+=("--workdir" "${BUILDKITE_PLUGIN_ANKA_WORKDIR:-.}")
fi

# Mount host directory (current directory by default)
if [[ -n "${BUILDKITE_PLUGIN_ANKA_VOLUME:-}" ]] ; then
  args+=("--volume" "${BUILDKITE_PLUGIN_ANKA_VOLUME:-}")
fi

# Prevent the mounting of the host directory
if [[ "${BUILDKITE_PLUGIN_ANKA_NO_VOLUME:-false}" =~ (true|on|1) ]] ; then
  args+=("--no-volume")
fi

# Inherit environment variables from host
if [[ "${BUILDKITE_PLUGIN_ANKA_INHERIT_ENVIRONMENT_VARS:-false}" =~ (true|on|1) ]] ; then
  args+=("--env")
fi

# Provide an environment variable file
if [[ -n "${BUILDKITE_PLUGIN_ANKA_ENVIRONMENT_FILE:-}" ]] ; then
  args+=("--env-file" "${BUILDKITE_PLUGIN_ANKA_ENVIRONMENT_FILE:-}")
fi

# Wait to start processing until network can be established
if [[ "${BUILDKITE_PLUGIN_ANKA_WAIT_NETWORK:-false}" =~ (true|on|1) ]] ; then
  args+=("--wait-network")
fi

args+=("$job_image_name")