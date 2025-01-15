#!/bin/bash

set -eux

echo "Check game port availability"
nc -nzuv "127.0.0.1" ${VR_GAME_PORT:-"9876"}

echo "Check query port availability"
nc -nzuv "127.0.0.1" ${VR_QUERY_PORT:-"9877"}

echo "Check for latest save time"
data=/vrising/data/Saves/v3/${VR_SAVE_NAME:-"world1"}/

# Find the last modified time of files in the Saves directory (in seconds since the epoch)
last_modified=$(find "$data" -type f -printf '%T@\n' | sort -rn | head -n 1)

# Convert the last_modified to an integer (strip off the fractional part)
last_modified_int=$(printf "%.0f" "$last_modified")

# Calculate the threshold time (last modified time + save interval in seconds)
last_modified_time=$(($last_modified_int + ${VR_SAVE_INTERVAL:-180}))

# Check if the threshold time is less than the current time
if [ "$last_modified_time" -lt "$(date +%s)" ]; then
    echo "No files updated in the last ${VR_SAVE_INTERVAL:-"180"} seconds"
else
    echo "Files updated in the last ${VR_SAVE_INTERVAL:-"180"} seconds"
fi
