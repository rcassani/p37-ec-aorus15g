#!/bin/bash

display_usage() {
# Prints Usage for set-fan-mode
  echo "Usage: $0 fan-mode [fan-speed]"
  echo "  fan-mode  : <Fan mode to set>"
  echo "  fan-speed : <Fan speed in % for \"fix\" and \"automax\" modes>"
  echo ""
  echo "Fan modes: normal | quiet | gaming | deepcontrol | fix | automax"
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

# If no args, or --help or --h, display usage
if [[ ${#@} == 0 || ( $@ == "--help") ||  $@ == "-h" ]]
  then
    display_usage
    exit 0
fi

# Check that mode is in the list
listModes="normal quiet gaming deepcontrol fix automax"
isValidMode="$(exists_in_list "$listModes" $1)"
if [[ $isValidMode -eq 0 ]]; then
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

# Set all fan mode bits to zero (normal mode)
p37ec-aorus15g 0x08.6 0
p37ec-aorus15g 0x06.4 0
p37ec-aorus15g 0x0D.0 0
p37ec-aorus15g 0x0D.7 0
p37ec-aorus15g 0x0C.4 0

# For all other cases
if [[ "$1" != "normal" ]]; then
  case $1 in
    quiet)
      p37ec-aorus15g 0x08.6 1
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
    deepcontrol)
      p37ec-aorus15g 0x0D.7 1
      ;;
    gaming)
      p37ec-aorus15g 0x0C.4 1
      ;;
    *)
      $0 normal
      ;;
  esac
fi
echo "Fan mode set to \"$1\"$extra"
