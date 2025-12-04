#!/bin/bash

# Install and configure TLP for laptop power management
# Creates 3 profiles: power-saver, balanced, performance

echo "Installing TLP for laptop power management..."

# Remove PPD if it exists (conflicts with TLP)
if pacman -Q power-profiles-daemon &>/dev/null; then
  sudo systemctl stop power-profiles-daemon.service 2>/dev/null || true
  sudo systemctl disable power-profiles-daemon.service 2>/dev/null || true
  sudo pacman -R --noconfirm power-profiles-daemon 2>/dev/null || true
fi

# Install TLP
sudo pacman -S --needed --noconfirm tlp

# Create TLP configuration directory
sudo mkdir -p /etc/tlp.d

# Create base TLP configuration (shared by all profiles)
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

# Create POWER-SAVER profile (force BAT mode even when plugged in)
sudo tee /etc/tlp.d/01-profile-power-saver.conf > /dev/null << 'EOF'
# Power Saver Profile - Maximum battery life
# Forces BAT (battery) settings even when on AC power

# CPU Settings - Maximum power saving
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave

CPU_ENERGY_PERF_POLICY_ON_AC=power
CPU_ENERGY_PERF_POLICY_ON_BAT=power

CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=50
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=30

CPU_BOOST_ON_AC=0
CPU_BOOST_ON_BAT=0

# GPU Settings - Power saving
RADEON_DPM_PERF_LEVEL_ON_AC=low
RADEON_DPM_PERF_LEVEL_ON_BAT=low

RADEON_POWER_PROFILE_ON_AC=low
RADEON_POWER_PROFILE_ON_BAT=low

# Platform Profile (if supported)
PLATFORM_PROFILE_ON_AC=low-power
PLATFORM_PROFILE_ON_BAT=low-power

# Disk Settings - Aggressive power saving
DISK_APM_LEVEL_ON_AC="128 128"
DISK_APM_LEVEL_ON_BAT="128 128"

SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# PCIe Active State Power Management
PCIE_ASPM_ON_AC=powersupersave
PCIE_ASPM_ON_BAT=powersupersave
EOF

# Create BALANCED profile (normal TLP auto-switching)
sudo tee /etc/tlp.d/01-profile-balanced.conf > /dev/null << 'EOF'
# Balanced Profile - Good balance of performance and battery life
# Uses different settings for AC vs BAT (normal TLP behavior)

# CPU Settings - Balanced
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave

CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=50

CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# GPU Settings - Balanced
RADEON_DPM_PERF_LEVEL_ON_AC=auto
RADEON_DPM_PERF_LEVEL_ON_BAT=low

RADEON_POWER_PROFILE_ON_AC=default
RADEON_POWER_PROFILE_ON_BAT=low

# Platform Profile (if supported)
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power

# Disk Settings - Balanced
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"

SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# PCIe Active State Power Management
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave
EOF

# Create PERFORMANCE profile (force AC mode even on battery)
sudo tee /etc/tlp.d/01-profile-performance.conf > /dev/null << 'EOF'
# Performance Profile - Maximum performance
# Forces AC (plugged in) settings even when on battery

# CPU Settings - Maximum performance
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=performance

CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=performance

CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=100
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=100

CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=1

# GPU Settings - Maximum performance
RADEON_DPM_PERF_LEVEL_ON_AC=high
RADEON_DPM_PERF_LEVEL_ON_BAT=high

RADEON_POWER_PROFILE_ON_AC=high
RADEON_POWER_PROFILE_ON_BAT=high

# Platform Profile (if supported)
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=performance

# Disk Settings - Performance
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="254 254"

SATA_LINKPWR_ON_AC=max_performance
SATA_LINKPWR_ON_BAT=max_performance

# PCIe Active State Power Management
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=default
EOF

# Only one profile can be active at a time, so disable the others by default
sudo mv /etc/tlp.d/01-profile-power-saver.conf /etc/tlp.d/01-profile-power-saver.conf.disabled
sudo mv /etc/tlp.d/01-profile-performance.conf /etc/tlp.d/01-profile-performance.conf.disabled

# Enable and start TLP service
chrootable_systemctl_enable tlp.service

# Mask systemd-rfkill services (TLP handles this)
sudo systemctl mask systemd-rfkill.service 2>/dev/null || true
sudo systemctl mask systemd-rfkill.socket 2>/dev/null || true

# Set default profile to balanced
mkdir -p "$HOME/.local/state/omarchy"
echo "balanced" > "$HOME/.local/state/omarchy/tlp-profile"

# Apply TLP settings if not in chroot
if [[ -z "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
  sudo tlp start 2>/dev/null || true
fi

echo "TLP installed and configured with 3 power profiles"
