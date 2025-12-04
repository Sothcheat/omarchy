#!/bin/bash

# Auto-detect appropriate power management system
# Laptops (with battery) → TLP
# Desktops (no battery) → PPD

echo "Detecting power management requirements..."

# Check if OMARCHY_POWER_MANAGEMENT is already set (ISO installer override)
if [[ -z "${OMARCHY_POWER_MANAGEMENT:-}" ]]; then
  # Auto-detect based on battery presence
  if ls /sys/class/power_supply/BAT* &>/dev/null 2>&1; then
    echo "Battery detected - Installing TLP for optimal laptop power management"
    export OMARCHY_POWER_MANAGEMENT="tlp"
  else
    echo "No battery detected - Installing PPD for desktop use"
    export OMARCHY_POWER_MANAGEMENT="ppd"
  fi
else
  echo "Power management system specified: $OMARCHY_POWER_MANAGEMENT"
fi

# Install the appropriate power management system
if [[ "$OMARCHY_POWER_MANAGEMENT" == "tlp" ]]; then
  source "$OMARCHY_INSTALL/config/hardware/tlp.sh"
else
  source "$OMARCHY_INSTALL/config/hardware/ppd.sh"
fi

echo "Power management configured: $OMARCHY_POWER_MANAGEMENT"
