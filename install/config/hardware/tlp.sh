#!/bin/bash

# Install and configure TLP for laptop power management
# Creates 3 profiles: power-saver, balanced, performance

# Source required helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../helpers/chroot.sh" 2>/dev/null || {
  # Fallback: define chrootable_systemctl_enable if not available
  chrootable_systemctl_enable() {
    if [[ -n "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
      sudo systemctl enable "$@"
    else
      sudo systemctl enable --now "$@"
    fi
  }
  export -f chrootable_systemctl_enable
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

# Create POWER-SAVER profile
echo "Creating power-saver profile..."
sudo tee /etc/tlp.d/01-profile-power-saver.conf > /dev/null << 'EOF'
# Power Saver Profile - Maximum battery life while maintaining responsiveness
# Target: Lowest wattage while staying snappy for browsing, reading, documents
# Philosophy: Aggressive power saving but NOT sluggish

# CPU Settings - Efficient but responsive
# Using powersave governor with balance_power EPP is more responsive than "power" EPP
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# balance_power EPP: Good balance of efficiency and responsiveness
# This is MORE responsive than "power" while still saving significant energy
CPU_ENERGY_PERF_POLICY_ON_AC=balance_power
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

# CPU Performance Limits
# 50-60% is the sweet spot: enough for browsing/documents, but very efficient
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=55
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=45

# Disable turbo boost - biggest battery saver
# Turbo uses 2-3x more power for only 20-30% more performance
CPU_BOOST_ON_AC=0
CPU_BOOST_ON_BAT=0

# GPU Settings - Low power but functional
RADEON_DPM_PERF_LEVEL_ON_AC=low
RADEON_DPM_PERF_LEVEL_ON_BAT=low
RADEON_POWER_PROFILE_ON_AC=low
RADEON_POWER_PROFILE_ON_BAT=low

# Platform Profile (ACPI platform_profile)
PLATFORM_PROFILE_ON_AC=low-power
PLATFORM_PROFILE_ON_BAT=low-power

# Disk Settings - Moderate power saving (not too aggressive to avoid lag)
# 192 = moderate spin down, 128 = more aggressive
# We use 192 on AC for responsiveness, 160 on BAT for battery with minimal lag
DISK_APM_LEVEL_ON_AC="192 192"
DISK_APM_LEVEL_ON_BAT="160 160"

# SATA link power - medium power saving (not max to avoid stutters)
SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# PCIe Active State Power Management - aggressive savings
PCIE_ASPM_ON_AC=powersupersave
PCIE_ASPM_ON_BAT=powersupersave

# Intel GPU frequency scaling (if Intel GPU present)
# Keep min freq at 300MHz, limit max for power savings
INTEL_GPU_MIN_FREQ_ON_AC=300
INTEL_GPU_MIN_FREQ_ON_BAT=300
INTEL_GPU_MAX_FREQ_ON_AC=700
INTEL_GPU_MAX_FREQ_ON_BAT=500

# USB Autosuspend - enabled for maximum savings
USB_AUTOSUSPEND=1
USB_BLACKLIST_WWAN=0
EOF

# Create BALANCED profile
echo "Creating balanced profile..."
sudo tee /etc/tlp.d/01-profile-balanced.conf > /dev/null << 'EOF'
# Balanced Profile - True balance between performance and battery life
# AC: Good performance WITHOUT excessive heat (NOT performance mode!)
# BAT: Snappy for coding/browsing while conserving battery (NOT power-saver mode!)
# Philosophy: The "Goldilocks" profile - just right for daily use

# CPU Settings - Adaptive based on AC/BAT
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# AC: balance_performance - responsive but NOT hot (NOT "performance" EPP!)
# BAT: balance_power - efficient but still snappy (NOT "power" EPP!)
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

# CPU Performance Limits - Critical for thermal management
# AC: 75% max - plenty for daily use, prevents excessive heat
#     This is the KEY to avoiding overheating on AC!
# BAT: 60% max - responsive for coding/browsing while saving battery
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=75
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=60

# Turbo Boost - Smart usage
# AC: Enable for burst performance (but 75% limit prevents sustained turbo = less heat)
# BAT: Disable to save battery
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# GPU Settings - Adaptive
RADEON_DPM_PERF_LEVEL_ON_AC=auto
RADEON_DPM_PERF_LEVEL_ON_BAT=low
RADEON_POWER_PROFILE_ON_AC=default
RADEON_POWER_PROFILE_ON_BAT=low

# Platform Profile - True balance
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power

# Disk Settings - Smart power management
# AC: 254 (performance) - no spin down delays
# BAT: 192 (moderate) - some power saving without noticeable lag
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="192 192"

# SATA link power - Balanced approach
SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# PCIe ASPM - Adaptive
# AC: default (no extra power saving, less risk of issues)
# BAT: powersave (moderate power saving)
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersave

# Intel GPU frequency scaling
# AC: Good range for daily tasks without excessive power draw
# BAT: Lower max to save battery while maintaining responsiveness
INTEL_GPU_MIN_FREQ_ON_AC=300
INTEL_GPU_MIN_FREQ_ON_BAT=300
INTEL_GPU_MAX_FREQ_ON_AC=1100
INTEL_GPU_MAX_FREQ_ON_BAT=800

# USB Autosuspend - enabled
USB_AUTOSUSPEND=1
USB_BLACKLIST_WWAN=0
EOF

# Create PERFORMANCE profile
echo "Creating performance profile..."
sudo tee /etc/tlp.d/01-profile-performance.conf > /dev/null << 'EOF'
# Performance Profile - Maximum performance WITHOUT overheating
# Target: Best performance while preventing thermal throttling
# Philosophy: High performance that's SUSTAINABLE (not thermal runaway)
# Key Insight: 95% performs almost as well as 100% but generates much less heat

# CPU Settings - High performance with thermal awareness
CPU_SCALING_GOVERNOR_ON_AC=powersave
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# "performance" EPP for maximum speed
# Note: Still using powersave governor as it handles boost better on modern CPUs
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_performance

# CPU Performance Limits - CRITICAL for thermal management
# AC: 95% max - This is the KEY to preventing overheating!
#     - 100% causes thermal throttling (CPU hits 95-100°C, throttles down)
#     - 95% prevents thermal runaway while giving 90-95% of max performance
#     - Much cooler, actually FASTER over time due to no throttling
# BAT: 80% max - Good performance without draining battery instantly
CPU_MIN_PERF_ON_AC=0
CPU_MAX_PERF_ON_AC=95
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=80

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

# Disk Settings - Maximum I/O performance
# 254 = no power saving, maximum performance
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="254 254"

# SATA link power - Maximum performance
# max_performance on AC for best I/O
# med_power on BAT to not drain battery too fast
SATA_LINKPWR_ON_AC=max_performance
SATA_LINKPWR_ON_BAT=med_power_with_dipm

# PCIe ASPM - Disabled for performance
# default = no power saving, no risk of compatibility issues
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=default

# Intel GPU - Maximum frequency
# Higher max freq for gaming/video work
INTEL_GPU_MIN_FREQ_ON_AC=300
INTEL_GPU_MIN_FREQ_ON_BAT=300
INTEL_GPU_MAX_FREQ_ON_AC=1500
INTEL_GPU_MAX_FREQ_ON_BAT=1200

# USB Autosuspend - enabled (doesn't affect performance)
USB_AUTOSUSPEND=1
USB_BLACKLIST_WWAN=0
EOF

# Verify all profile files were created
echo "Verifying profile files..."
PROFILES_OK=true
for profile in power-saver balanced performance; do
  if [[ ! -f "/etc/tlp.d/01-profile-${profile}.conf" ]]; then
    echo "Error: Failed to create profile: $profile" >&2
    PROFILES_OK=false
  else
    echo "✓ Profile created: $profile"
  fi
done

if [[ "$PROFILES_OK" != "true" ]]; then
  echo "Error: Some TLP profiles failed to create" >&2
  exit 1
fi

# Only one profile can be active at a time, so disable the others by default
echo "Setting up profile management (activating balanced)..."
sudo mv /etc/tlp.d/01-profile-power-saver.conf /etc/tlp.d/01-profile-power-saver.conf.disabled 2>/dev/null || true
sudo mv /etc/tlp.d/01-profile-performance.conf /etc/tlp.d/01-profile-performance.conf.disabled 2>/dev/null || true

# Verify the balanced profile is active
if [[ ! -f /etc/tlp.d/01-profile-balanced.conf ]]; then
  echo "Error: Balanced profile not found after setup" >&2
  exit 1
fi
echo "✓ Balanced profile is active"

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
if ! sudo visudo -c -f /etc/sudoers.d/omarchy-tlp &>/dev/null; then
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

echo "✓ TLP installed and configured with 3 optimized power profiles successfully"
