#!/bin/bash

# Shared battery detection functions
# Used by both installation and runtime scripts

# Check if system has a battery
has_battery() {
  # Check for battery in power_supply
  if ls /sys/class/power_supply/BAT* &>/dev/null 2>&1; then
    return 0
  fi

  if [[ -d /sys/class/power_supply/battery ]]; then
    return 0
  fi

  # Check via ACPI if available
  if command -v acpi &>/dev/null; then
    if acpi -b 2>/dev/null | grep -qi "battery"; then
      return 0
    fi
  fi

  # Check via upower if available
  if command -v upower &>/dev/null; then
    if upower -e | grep -qi "battery"; then
      return 0
    fi
  fi

  # No battery found
  return 1
}

# Check if battery threshold control is supported
has_battery_threshold_support() {
  # First check if battery exists
  if ! has_battery; then
    return 1
  fi

  # Check for threshold control files
  for path in /sys/class/power_supply/BAT*/charge_control_end_threshold \
              /sys/class/power_supply/battery/charge_control_end_threshold; do
    if [[ -f "$path" ]]; then
      return 0
    fi
  done

  return 1
}

# Export functions if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f has_battery
  export -f has_battery_threshold_support
fi
