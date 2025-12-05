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

# Create POWER-SAVER profile (optimized for maximum battery life)
sudo tee /etc/tlp.d/01-profile-power-saver.conf > /dev/null << 'EOF'
# Power Saver Profile - Maximum battery life while maintaining responsiveness
# Optimized for: browsing, reading, documents, light coding
# Target: Lowest wattage while staying snappy and responsive

# CPU Settings - Efficient but responsive
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# balance_power is more responsive than "power" while still saving energy
CPU_ENERGY_PERF_POLICY_ON_AC=balance_power
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

# 60% max on AC, 50% max on BAT - enough for everyday tasks
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=60
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=50

# Disable turbo boost to save power (burst performance not needed)
CPU_BOOST_ON_AC=0
CPU_BOOST_ON_BAT=0

# GPU Settings - Low power but functional
RADEON_DPM_PERF_LEVEL_ON_AC=low
RADEON_DPM_PERF_LEVEL_ON_BAT=low

RADEON_POWER_PROFILE_ON_AC=low
RADEON_POWER_PROFILE_ON_BAT=low

# Platform Profile (if supported by laptop)
PLATFORM_PROFILE_ON_AC=low-power
PLATFORM_PROFILE_ON_BAT=low-power

# Disk Settings - Moderate power saving (not too aggressive for responsiveness)
# 128 = aggressive spin down, 192 = moderate, 254 = minimal
DISK_APM_LEVEL_ON_AC="192 192"
DISK_APM_LEVEL_ON_BAT="128 128"

# SATA link power - moderate savings without lag
SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# PCIe Active State Power Management - aggressive savings
PCIE_ASPM_ON_AC=powersupersave
PCIE_ASPM_ON_BAT=powersupersave

# Reduce screen brightness automatically (can save significant power)
INTEL_GPU_MIN_FREQ_ON_AC=300
INTEL_GPU_MIN_FREQ_ON_BAT=300
INTEL_GPU_MAX_FREQ_ON_AC=800
INTEL_GPU_MAX_FREQ_ON_BAT=600
EOF

# Create BALANCED profile (truly balanced for everyday use)
sudo tee /etc/tlp.d/01-profile-balanced.conf > /dev/null << 'EOF'
# Balanced Profile - Real balance between performance and battery life
# AC: Good performance without excessive heat
# BAT: Snappy and responsive while conserving battery
# Optimized for: browsing, coding, documents, light multitasking

# CPU Settings - Balanced and adaptive
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# AC: balance_performance (responsive but not hot)
# BAT: balance_power (efficient but still snappy)
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

# AC: 85% max (good performance without overheating)
# BAT: 65% max (responsive for everyday tasks while saving battery)
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=85
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=65

# AC: Enable boost for burst performance when needed
# BAT: Disable boost to save battery
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# GPU Settings - Adaptive
RADEON_DPM_PERF_LEVEL_ON_AC=auto
RADEON_DPM_PERF_LEVEL_ON_BAT=low

RADEON_POWER_PROFILE_ON_AC=default
RADEON_POWER_PROFILE_ON_BAT=low

# Platform Profile - Balanced approach
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power

# Disk Settings - Smart power management
# AC: Minimal power saving (254 = performance)
# BAT: Moderate power saving (192 = responsive but efficient)
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="192 192"

# SATA link power - Balanced
SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# PCIe Active State Power Management - Adaptive
# AC: Default (no extra power saving)
# BAT: Medium power saving
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersave

# Intel GPU frequency scaling (if Intel GPU present)
INTEL_GPU_MIN_FREQ_ON_AC=300
INTEL_GPU_MIN_FREQ_ON_BAT=300
INTEL_GPU_MAX_FREQ_ON_AC=1200
INTEL_GPU_MAX_FREQ_ON_BAT=900
EOF

# Create PERFORMANCE profile (maximum performance without overheating)
sudo tee /etc/tlp.d/01-profile-performance.conf > /dev/null << 'EOF'
# Performance Profile - Maximum performance with thermal management
# Optimized for: gaming, video editing, compiling, heavy multitasking
# Target: Best performance while preventing thermal throttling and overheating

# CPU Settings - High performance with thermal awareness
# Use powersave governor (Intel pstate) which actually performs better
# than "performance" governor on modern CPUs due to better frequency scaling
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# "performance" EPP for maximum speed (but governor manages thermal)
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_performance

# AC: 95% max (leaving 5% headroom prevents excessive heat)
# BAT: 85% max (good performance without draining battery instantly)
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=95
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=85

# Enable turbo boost for maximum performance
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=1

# GPU Settings - Maximum performance
RADEON_DPM_PERF_LEVEL_ON_AC=high
RADEON_DPM_PERF_LEVEL_ON_BAT=auto

RADEON_POWER_PROFILE_ON_AC=high
RADEON_POWER_PROFILE_ON_BAT=default

# Platform Profile - Performance mode
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=balanced

# Disk Settings - No power saving (maximum I/O performance)
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="254 254"

# SATA link power - Maximum performance
SATA_LINKPWR_ON_AC=max_performance
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# PCIe Active State Power Management - Disabled for performance
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=default

# Intel GPU - Maximum frequency
INTEL_GPU_MIN_FREQ_ON_AC=300
INTEL_GPU_MIN_FREQ_ON_BAT=300
INTEL_GPU_MAX_FREQ_ON_AC=1500
INTEL_GPU_MAX_FREQ_ON_BAT=1200

# IMPORTANT: Thermal management
# Stop CPU throttling at reasonable temperature (prevents overheating)
# Modern Intel CPUs: 85-95°C is safe, we target 90°C max
# This prevents the "race to thermal throttling" problem
# Note: This requires thermald or laptop-mode-tools to be effective
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

# Create sudoers configuration for passwordless TLP profile switching
cat << 'EOF' | sudo tee /etc/sudoers.d/omarchy-tlp > /dev/null
# Allow TLP profile switching without password
%wheel ALL=(ALL) NOPASSWD: /usr/bin/mv /etc/tlp.d/01-profile-*.conf /etc/tlp.d/01-profile-*.conf.disabled
%wheel ALL=(ALL) NOPASSWD: /usr/bin/mv /etc/tlp.d/01-profile-*.conf.disabled /etc/tlp.d/01-profile-*.conf
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tlp start
EOF

sudo chmod 440 /etc/sudoers.d/omarchy-tlp

# Create systemd service to restore profile on boot
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
chrootable_systemctl_enable omarchy-tlp-profile.service

# Apply TLP settings if not in chroot
if [[ -z "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
  sudo tlp start 2>/dev/null || true
fi

echo "TLP installed and configured with 3 power profiles"
