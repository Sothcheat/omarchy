#!/bin/bash

# Install and configure Power Profiles Daemon (PPD)
# Used for desktops and systems without battery

echo "Installing Power Profiles Daemon..."

# Remove TLP if it exists (in case of reinstall)
if pacman -Q tlp &>/dev/null; then
  sudo pacman -R --noconfirm tlp tlp-rdw 2>/dev/null || true
fi

# Install PPD
sudo pacman -S --needed --noconfirm power-profiles-daemon

# Enable and start service
chrootable_systemctl_enable power-profiles-daemon.service

# Set default profile
if [[ -z "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
  # Not in chroot, can set profile immediately
  powerprofilesctl set balanced 2>/dev/null || true
fi

echo "Power Profiles Daemon installed successfully"
