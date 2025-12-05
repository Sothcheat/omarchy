#!/bin/bash

# Install and configure Power Profiles Daemon (PPD)
# Used for desktops and systems without battery

# Source required helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../helpers/chroot.sh" 2>/dev/null || {
  # Fallback: define chrootable_systemctl_enable if not available
  chrootable_systemctl_enable() {
    if [[ -n "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
      sudo systemctl --root="${OMARCHY_CHROOT_INSTALL}" enable "$@" 2>/dev/null || true
    else
      sudo systemctl enable "$@"
    fi
  }
}

echo "Installing Power Profiles Daemon..."

# Remove TLP if it exists (in case of reinstall)
if pacman -Q tlp &>/dev/null; then
  echo "Removing conflicting TLP installation..."
  sudo pacman -R --noconfirm tlp tlp-rdw 2>/dev/null || true
fi

# Install PPD
echo "Installing power-profiles-daemon package..."
if ! sudo pacman -S --needed --noconfirm power-profiles-daemon; then
  echo "Error: Failed to install power-profiles-daemon" >&2
  exit 1
fi

# Enable and start service
echo "Enabling power-profiles-daemon service..."
if ! chrootable_systemctl_enable power-profiles-daemon.service; then
  echo "Warning: Failed to enable power-profiles-daemon service" >&2
fi

# Set default profile (only if not in chroot)
if [[ -z "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
  echo "Setting default power profile to balanced..."
  if command -v powerprofilesctl &>/dev/null; then
    powerprofilesctl set balanced 2>/dev/null || echo "Note: Could not set default profile (will apply on next boot)"
  fi
fi

echo "Power Profiles Daemon installed successfully"
