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

# Convert release versions into integers for easier version compare
# 25.11 -> 2511
# 25.05 -> 2505
CURRENT_RELEASE=$(cut -c1-2,4-5 /run/booted-system/nixos-version)
LATEST_RELEASE=$(cut -c1-2,4-5 "${LATEST}/nixos-version")

IS_UPGRADE="false"

if (( CURRENT_RELEASE > LATEST_RELEASE )); then
    # release downgrade
    echo "ERROR: The current NixOS release is newer than the downloaded one"
    echo "Current: $CURRENT_RELEASE"
    echo "Downloaded: $LATEST_RELEASE"
    echo "Will not perform a downgrade! Exiting"
    exit 1
elif (( CURRENT_RELEASE < LATEST_RELEASE )); then
    # relase upgrade
    echo "WARN: The downloaded generation is a newer NixOS relase."
    echo "Will NOT perform a switch operation, to avoid problems!"
    IS_UPGRADE="true"
fi

if [[ "${LATEST_KERNEL}" == "${BOOTED_KERNEL}" ]]; then
    echo "Latest generation is on the same kernel"

    if [[ "${ALLOW_SWITCH:-true}" == "true" && ${IS_UPGRADE} == "false" ]]; then
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
    elif [[ "${ALLOW_SWITCH:-true}" == "true" && ${IS_UPGRADE} == "false" ]]; then
        echo "Executing switch into new generation"
        "${LATEST}/bin/switch-to-configuration" switch
    else
        echo "ERROR: No action (kexec, boot, switch) allowed. Exiting"
        exit 1
    fi
fi
