#!/bin/bash

display_usage() {
# Prints Usage for set-fan-mode
  echo "Usage: $(basename $0) [fan-mode] [fan-speed]"
  echo ""
  echo "Without arguments: display current fan mode"
  echo ""
  echo "Arguments:"
  echo "  fan-mode  : <Fan mode to set>"
  echo "  fan-speed : <Fan speed in % for \"fix\" and \"automax\" modes>"
  echo ""
  echo "Fan modes: normal | quiet | gaming | deepcontrol | fix | automax"
  echo ""
  echo "Examples:"
  echo "  $(basename $0)            # display current fan mode"
  echo "  $(basename $0) normal     # set fan mode to \"normal\""
  echo "  $(basename $0) fix 50     # set fan mode to \"fix\" with fan speed 50%"
  echo ""
  echo "See: https://github.com/rcassani/p37-ec-aorus15g"
  }

exists_in_list() {
# Function for determine if a word is in a space-separated list
  list=$1
  word=$2
  if [[ "$list" =~ (" "|^)$word(" "|$) ]]; then
    echo 1
  else
    echo 0
  fi
}

validate_fan_speed() {
  speed=$1
  if [[ "$speed" -lt 30 || "$speed" -gt 100 ]]; then
    echo "0x00"
  else
    speed_dec=$(($speed * 229 / 100))
    echo $(printf '0x%X' $speed_dec)
  fi
}

# If --help or --h, display usage
if [[ ( $@ == "--help") ||  $@ == "-h" ]]
  then
    display_usage
    exit 0
fi

# Check that mode is in the list
listModes="normal quiet gaming deepcontrol fix automax"
isValidMode="$(exists_in_list "$listModes" $1)"
if [[ -n "$1" && $isValidMode -eq 0 ]]; then
  echo "Fan mode \"$1\" is not supported"
  exit 1
fi

# Check that it has fan-speed if needed
if [[ "$1" == "fix" || "$1" == "automax" ]]; then
  if [[ "$#" -ne 2 ]]; then
    echo "Fan speed % is needed for \"$1\" mode"
      exit 1
  else
    fan_speed_hex="$(validate_fan_speed $2)"
    if [[ "$fan_speed_hex" == "0x00" ]]; then
      echo "Fan speed needs to be > 30% and < 100%"
      exit 1
    fi
    extra=", fan speed: $2%"
  fi
fi

# For all other cases
if [[ -n "$1" ]]; then
  fan_mode="$1"
  # Set all fan mode bits to zero (normal mode)
  p37ec-aorus15g 0x08.6 0
  p37ec-aorus15g 0x06.4 0
  p37ec-aorus15g 0x0D.0 0
  p37ec-aorus15g 0x0D.7 0
  p37ec-aorus15g 0x0C.4 0
  # Set additional bits for the different fan modes
  case $1 in
    normal)
      # nothing
      ;;
    quiet)
      p37ec-aorus15g 0x08.6 1
      ;;
    gaming)
      p37ec-aorus15g 0x0C.4 1
      ;;
    deepcontrol)
      p37ec-aorus15g 0x0D.7 1
      ;;
    fix)
      p37ec-aorus15g 0xB0 "$fan_speed_hex"
      p37ec-aorus15g 0xB1 "$fan_speed_hex"
      p37ec-aorus15g 0x06.4 1
      ;;
    automax)
      p37ec-aorus15g 0xB0 $fan_speed_hex
      p37ec-aorus15g 0xB1 $fan_speed_hex
      p37ec-aorus15g 0x0D.0 1
      ;;
  esac
  echo "Fan mode set to: \"$fan_mode\"$extra"
else
  # Get fan mode
  fan_mode="normal"
  if [[ $(p37ec-aorus15g "0x08.6") -eq 1 ]]; then
    fan_mode="quiet"
  fi
  if [[ $(p37ec-aorus15g "0x0C.4") -eq 1 ]]; then
    fan_mode="gaming"
  fi
  if [[ $(p37ec-aorus15g "0x0D.7") -eq 1 ]]; then
    fan_mode="deepcontrol"
  fi
  if [[ $(p37ec-aorus15g "0x06.4") -eq 1 ]]; then
    fan_mode="fix"
  fi
  if [[ $(p37ec-aorus15g "0x0D.0") -eq 1 ]]; then
    fan_mode="automax"
  fi
  # Get fan speed if needed
  if [[ "$fan_mode" == "fix" || "$fan_mode" == "automax" ]]; then
    fan_speed_hex=$(p37ec-aorus15g "0xB0")
    fan_speed=$(( (fan_speed_hex * 100 + 114) / 229 )) # round(fan_speed_hex/2.29)
    extra=", fan speed: $fan_speed%"
  fi
  echo "Fan current mode: \"$fan_mode\"$extra"
fi
