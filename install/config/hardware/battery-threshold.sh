#!/bin/bash

# Install battery charge threshold configuration
# Only runs if the system has a battery with threshold support

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

# Source battery detection helper
source "$SCRIPT_DIR/../../helpers/battery-detection.sh" 2>/dev/null || {
  # Fallback: inline battery detection
  has_battery() {
    if ls /sys/class/power_supply/BAT* &>/dev/null 2>&1; then
      return 0
    fi
    if [[ -d /sys/class/power_supply/battery ]]; then
      return 0
    fi
    return 1
  }

  has_battery_threshold_support() {
    if ! has_battery; then
      return 1
    fi
    for path in /sys/class/power_supply/BAT*/charge_control_end_threshold \
                /sys/class/power_supply/battery/charge_control_end_threshold; do
      if [[ -f "$path" ]]; then
        return 0
      fi
    done
    return 1
  }
}

# Check for battery
if ! has_battery; then
  echo "No battery detected - skipping battery threshold configuration (desktop system)"
  exit 0
fi

echo "Battery detected - checking threshold control support..."

# Check for threshold control support
if ! has_battery_threshold_support; then
  echo "Battery charge threshold control not supported on this hardware"
  echo "Your laptop may not support this feature (depends on manufacturer)"
  exit 0
fi

echo "Battery threshold control supported - configuring..."

# Find the actual threshold file
THRESHOLD_FILE=""
for path in /sys/class/power_supply/BAT*/charge_control_end_threshold \
            /sys/class/power_supply/battery/charge_control_end_threshold; do
  if [[ -f "$path" ]]; then
    THRESHOLD_FILE="$path"
    echo "Found threshold control: $path"
    break
  fi
done

# Double-check (should never happen after has_battery_threshold_support check)
if [[ -z "$THRESHOLD_FILE" ]]; then
  echo "Error: Threshold file not found despite support check" >&2
  exit 0
fi

# Install sudoers configuration for passwordless threshold changes
echo "Creating sudoers configuration..."
cat << 'EOF' | sudo tee /etc/sudoers.d/omarchy-battery-threshold > /dev/null
# Allow battery charge threshold control without password
# Note: These paths are kernel-controlled and safe to modify
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/power_supply/BAT[0-9]/charge_control_end_threshold
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/power_supply/BAT[0-9][0-9]/charge_control_end_threshold
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/power_supply/battery/charge_control_end_threshold
EOF

sudo chmod 440 /etc/sudoers.d/omarchy-battery-threshold || {
  echo "Error: Failed to set sudoers permissions" >&2
  sudo rm -f /etc/sudoers.d/omarchy-battery-threshold
  exit 1
}

# Validate sudoers syntax
if ! sudo visudo -c -f /etc/sudoers.d/omarchy-battery-threshold &>/dev/null; then
  echo "Error: Invalid sudoers syntax" >&2
  sudo rm -f /etc/sudoers.d/omarchy-battery-threshold
  exit 1
fi

echo "Sudoers configuration created successfully"

# Create systemd service to restore threshold on boot
echo "Creating threshold restoration service..."
cat << EOF | sudo tee /etc/systemd/system/omarchy-battery-threshold.service > /dev/null
[Unit]
Description=Restore Battery Charge Threshold on Boot
After=multi-user.target

[Service]
Type=oneshot
User=$USER
Environment="HOME=$HOME"
ExecStart=$HOME/.local/share/omarchy/bin/omarchy-battery-threshold-restore
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
echo "Enabling threshold restoration service..."
if ! chrootable_systemctl_enable omarchy-battery-threshold.service; then
  echo "Warning: Failed to enable omarchy-battery-threshold service" >&2
fi

# Set default threshold to 80% for battery health
echo "Setting default threshold to 80%..."
if ! mkdir -p "$HOME/.local/state/omarchy" 2>/dev/null; then
  echo "Warning: Failed to create state directory" >&2
fi

if ! echo "80" > "$HOME/.local/state/omarchy/battery-threshold" 2>/dev/null; then
  echo "Warning: Failed to save default threshold" >&2
fi

# Apply the threshold immediately if not in chroot
if [[ -z "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
  if [[ -x "$HOME/.local/share/omarchy/bin/omarchy-battery-threshold-set" ]]; then
    echo "Applying threshold immediately..."
    "$HOME/.local/share/omarchy/bin/omarchy-battery-threshold-set" 80 2>/dev/null || {
      echo "Note: Threshold will be applied on next boot"
    }
  else
    echo "Note: Threshold will be applied on next boot"
  fi
fi

echo "Battery charge threshold configured successfully"
