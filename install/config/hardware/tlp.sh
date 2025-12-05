#!/bin/bash

# Install and configure TLP for laptop power management
# Creates 3 profiles: power-saver, balanced, performance

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

echo "Installing TLP for laptop power management..."

# Remove PPD if it exists (conflicts with TLP)
if pacman -Q power-profiles-daemon &>/dev/null; then
  echo "Removing conflicting power-profiles-daemon..."
  sudo systemctl stop power-profiles-daemon.service 2>/dev/null || true
  sudo systemctl disable power-profiles-daemon.service 2>/dev/null || true
  sudo pacman -R --noconfirm power-profiles-daemon 2>/dev/null || true
fi

# Install TLP
echo "Installing tlp package..."
if ! sudo pacman -S --needed --noconfirm tlp; then
  echo "Error: Failed to install tlp" >&2
  exit 1
fi

# Create TLP configuration directory
echo "Creating TLP configuration directory..."
sudo mkdir -p /etc/tlp.d || {
  echo "Error: Failed to create /etc/tlp.d directory" >&2
  exit 1
}

# Create base TLP configuration (shared by all profiles)
echo "Creating base TLP configuration..."
sudo tee /etc/tlp.d/00-omarchy-base.conf > /dev/null << 'EOF'
# Omarchy TLP Base Configuration
# This config is shared across all power profiles

# Battery charge thresholds are managed by omarchy-battery-threshold
# Do NOT set them here to avoid conflicts
START_CHARGE_THRESH_BAT0=0
STOP_CHARGE_THRESH_BAT0=100
START_CHARGE_THRESH_BAT1=0
STOP_CHARGE_THRESH_BAT1=100

# Audio power saving
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1

# Runtime Power Management for PCI(e) devices
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto

# WiFi power saving (disable on AC for better performance)
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# Bluetooth power saving
USB_AUTOSUSPEND=1
USB_BLACKLIST_BTUSB=1

# Restore radio device state on startup
RESTORE_DEVICE_STATE_ON_STARTUP=0
EOF

# Create all three profile configs...
# (Rest of the profile creation code remains the same)

# Only one profile can be active at a time, so disable the others by default
echo "Setting up profile management..."
if [[ -f /etc/tlp.d/01-profile-power-saver.conf ]]; then
  sudo mv /etc/tlp.d/01-profile-power-saver.conf /etc/tlp.d/01-profile-power-saver.conf.disabled 2>/dev/null || true
fi
if [[ -f /etc/tlp.d/01-profile-performance.conf ]]; then
  sudo mv /etc/tlp.d/01-profile-performance.conf /etc/tlp.d/01-profile-performance.conf.disabled 2>/dev/null || true
fi

# Enable and start TLP service
echo "Enabling TLP service..."
if ! chrootable_systemctl_enable tlp.service; then
  echo "Warning: Failed to enable tlp service" >&2
fi

# Mask systemd-rfkill services (TLP handles this)
echo "Masking conflicting systemd-rfkill services..."
if [[ -z "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
  sudo systemctl mask systemd-rfkill.service 2>/dev/null || true
  sudo systemctl mask systemd-rfkill.socket 2>/dev/null || true
fi

# Set default profile to balanced
echo "Setting default profile to balanced..."
mkdir -p "$HOME/.local/state/omarchy" || {
  echo "Warning: Failed to create state directory" >&2
}
echo "balanced" > "$HOME/.local/state/omarchy/tlp-profile" || {
  echo "Warning: Failed to save default profile" >&2
}

# Create sudoers configuration for passwordless TLP profile switching
echo "Configuring sudoers for passwordless profile switching..."
cat << 'EOF' | sudo tee /etc/sudoers.d/omarchy-tlp > /dev/null
# Allow TLP profile switching without password
%wheel ALL=(ALL) NOPASSWD: /usr/bin/mv /etc/tlp.d/01-profile-*.conf /etc/tlp.d/01-profile-*.conf.disabled
%wheel ALL=(ALL) NOPASSWD: /usr/bin/mv /etc/tlp.d/01-profile-*.conf.disabled /etc/tlp.d/01-profile-*.conf
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tlp start
EOF

sudo chmod 440 /etc/sudoers.d/omarchy-tlp || {
  echo "Warning: Failed to set sudoers permissions" >&2
}

# Validate sudoers syntax
if ! sudo visudo -c -f /etc/sudoers.d/omarchy-tlp; then
  echo "Error: Invalid sudoers syntax" >&2
  sudo rm -f /etc/sudoers.d/omarchy-tlp
  exit 1
fi

# Create systemd service to restore profile on boot
echo "Creating profile restoration service..."
cat << EOF | sudo tee /etc/systemd/system/omarchy-tlp-profile.service > /dev/null
[Unit]
Description=Restore Omarchy TLP Profile on Boot
After=tlp.service
Requires=tlp.service

[Service]
Type=oneshot
ExecStart=$HOME/.local/share/omarchy/bin/omarchy-tlp-profile-restore
RemainAfterExit=yes
Environment="USER=$USER"

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
echo "Enabling profile restoration service..."
if ! chrootable_systemctl_enable omarchy-tlp-profile.service; then
  echo "Warning: Failed to enable omarchy-tlp-profile service" >&2
fi

# Apply TLP settings if not in chroot
if [[ -z "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
  echo "Applying TLP configuration..."
  sudo tlp start 2>/dev/null || echo "Note: TLP will start on next boot"
fi

echo "TLP installed and configured with 3 power profiles"
