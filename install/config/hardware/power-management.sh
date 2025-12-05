#!/bin/bash

# Auto-detect appropriate power management system
# Laptops (with battery) → TLP
# Desktops (no battery) → PPD

echo "Detecting power management requirements..."

# Function to detect battery presence
has_battery() {
  # Check multiple locations for battery
  if ls /sys/class/power_supply/BAT* &>/dev/null 2>&1; then
    return 0
  fi

  if ls /sys/class/power_supply/battery &>/dev/null 2>&1; then
    return 0
  fi

  # Check ACPI
  if command -v acpi &>/dev/null; then
    if acpi -b 2>/dev/null | grep -q "Battery"; then
      return 0
    fi
  fi

  # No battery found
  return 1
}

# Check if OMARCHY_POWER_MANAGEMENT is already set (ISO installer override)
if [[ -z "${OMARCHY_POWER_MANAGEMENT:-}" ]]; then
  # Auto-detect based on battery presence
  if has_battery; then
    echo "Battery detected - Installing TLP for optimal laptop power management"
    export OMARCHY_POWER_MANAGEMENT="tlp"
  else
    echo "No battery detected - Installing PPD for desktop use"
    export OMARCHY_POWER_MANAGEMENT="ppd"
  fi
else
  echo "Power management system specified: $OMARCHY_POWER_MANAGEMENT"

  # Validate specified system
  case "$OMARCHY_POWER_MANAGEMENT" in
    tlp|ppd)
      # Valid
      ;;
    *)
      echo "Error: Invalid OMARCHY_POWER_MANAGEMENT value: $OMARCHY_POWER_MANAGEMENT" >&2
      echo "Valid values: tlp, ppd" >&2
      exit 1
      ;;
  esac
fi

# Validate that the target script exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$SCRIPT_DIR/${OMARCHY_POWER_MANAGEMENT}.sh"

if [[ ! -f "$TARGET_SCRIPT" ]]; then
  echo "Error: Installation script not found: $TARGET_SCRIPT" >&2
  exit 1
fi

# Install the appropriate power management system
echo "Installing power management system from: $TARGET_SCRIPT"
if ! source "$TARGET_SCRIPT"; then
  echo "Error: Failed to install $OMARCHY_POWER_MANAGEMENT" >&2
  exit 1
fi

echo "Power management configured: $OMARCHY_POWER_MANAGEMENT"
