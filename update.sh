#!/usr/bin/env bash
set -euo pipefail

CURRENT=$(readlink -f /run/current-system)
LATEST=$(curl --fail "${LATEST_CLOSURE_ENDPOINT_URL}")

if [[ "${LATEST}" == "${CURRENT}" ]]; then
    echo "Already running on latest system closure"
    exit 0
fi

echo "Found a newer system closure: ${LATEST}"

# Get system closure
if ! nix-store --realise "${LATEST}"; then
  echo "ERROR: Failed to pull latest system closure"
  exit 1
fi

# Add new closure as a system closure
nix-env --profile /nix/var/nix/profiles/system --set "${LATEST}"

LATEST_KERNEL=$(readlink -f "${LATEST}/kernel")
BOOTED_KERNEL=$(readlink -f /run/booted-system/kernel)

if [[ "${LATEST_KERNEL}" == "${BOOTED_KERNEL}" ]]; then
    echo "Latest generation is on the same kernel"

    if [[ "${ALLOW_SWITCH:-true}" == "true" ]]; then
        echo "Executing switch into new generation"
        "${LATEST}/bin/switch-to-configuration" switch
    else
        echo "Setting as default for next boot"
        "${LATEST}/bin/switch-to-configuration" boot
    fi
else
    echo "Latest generation uses a newer kernel"

    if [[ "${ALLOW_KEXEC:-false}" == "true" ]]; then
        echo "Executing kexec into new generation"
        "${LATEST}/bin/switch-to-configuration" boot
        systemctl kexec
    elif [[ "${ALLOW_REBOOT:-false}" == "true" ]]; then
        echo "Executing reboot into new generation"
        "${LATEST}/bin/switch-to-configuration" boot
        systemctl reboot
    elif [[ "${ALLOW_SWITCH:-true}" == "true" ]]; then
        echo "Executing switch into new generation"
        "${LATEST}/bin/switch-to-configuration" switch
    else
        echo "ERROR: No action (kexec, boot, switch) allowed. Exiting"
        exit 1
    fi
fi
