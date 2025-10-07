#! /usr/bin/env bash
set -eu

CURRENT=$(readlink -f /run/current-system)
BOOTET=$(readlink -f /run/booted-system)

# Get latest closure
LATEST=$(curl --silent ${UPDATE_ENDPOINT}/${HOSTNAME}/latest-system-closure)
if [[ $? != 0 ]]; then
    echo "Couldn't call update endpoint to get latest system version"
    exit 1
fi

if [[ "${LATEST}" == "${CURRENT}" ]]; then
    echo "Already running on latest system closure."
    exit
fi

echo "Found a newer system closure"

# Get system closure
if ! nix-store -r ${LATEST} > /dev/null; then
  echo "Failed to pull latest system closure. Is your cache correctly configured?"
  exit 1
fi

LATEST_KERNEL=$(readlink -f ${LATEST}/kernel)
RUNNING_KERNEL=$(readlink -f ${BOOTET}/kernel)

if [[ "${LATEST_KERNEL}" == "${RUNNING_KERNEL}" ]]; then
    echo "Runnig  the same kernel as the latest system closure."
    ${LATEST}/bin/switch-to-configuration switch
else
    if [[ "${UNATTENDED_REBOOT:-false}" == "true" ]]; then # Set default value, to never unintentionally reboot
        echo "The latest closure has a newer kernel. We need to reboot"
        ${LATEST}/bin/switch-to-configuration boot
        systemctl reboot
    else
        echo "The latest closure has a newer kernel, but 'unattendedReboot' is not set. Only switching"
        ${LATEST}/bin/switch-to-configuration switch
    fi
fi
