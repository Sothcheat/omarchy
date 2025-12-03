#!/bin/bash

# Install battery charge threshold configuration
# Only runs if the system has a battery

if ls /sys/class/power_supply/BAT* &>/dev/null; then
  echo "Configuring battery charge threshold control..."

  # Install sudoers configuration for passwordless threshold changes
  cat << 'EOF' | sudo tee /etc/sudoers.d/omarchy-battery-threshold > /dev/null
# Allow battery charge threshold control without password
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/power_supply/BAT*/charge_control_end_threshold
%wheel ALL=(ALL) NOPASSWD: /usr/bin/tee /sys/class/power_supply/battery/charge_control_end_threshold
EOF

  sudo chmod 440 /etc/sudoers.d/omarchy-battery-threshold

  # Create systemd service to restore threshold on boot
  cat << EOF | sudo tee /etc/systemd/system/omarchy-battery-threshold.service > /dev/null
[Unit]
Description=Restore Battery Charge Threshold on Boot
After=multi-user.target

[Service]
Type=oneshot
User=$USER
ExecStart=$HOME/.local/share/omarchy/bin/omarchy-battery-threshold-restore
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  # Enable the service
  chrootable_systemctl_enable omarchy-battery-threshold.service

  # Set default threshold to 80% for battery health
  mkdir -p "$HOME/.local/state/omarchy"
  echo "80" > "$HOME/.local/state/omarchy/battery-threshold"

  # Apply the threshold immediately if not in chroot
  if [[ -z "${OMARCHY_CHROOT_INSTALL:-}" ]]; then
    $HOME/.local/share/omarchy/bin/omarchy-battery-threshold-set 80
  fi

  echo "Battery charge threshold configured successfully"
else
  echo "No battery detected, skipping battery threshold configuration"
fi
