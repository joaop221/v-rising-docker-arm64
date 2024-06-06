#!/bin/bash

set -eux

server=/vrising/server
data=/vrising/data

term_handler() {
	echo "Shutting down Server"

	PID=$(pgrep -f "^${server}/VRisingServer.exe")
	if [[ -z $PID ]]; then
		echo "Could not find VRisingServer.exe pid. Assuming server is dead..."
	else
		kill -n 15 "$PID"
		wait "$PID"
	fi
	wineserver -k
	sleep 1
	exit
}

trap 'term_handler' SIGTERM

echo " "
echo "Updating V-Rising Dedicated Server files..."
echo " "
LD_LIBRARY_PATH="/home/steam/steamcmd/linux32/:$LD_LIBRARY_PATH" box86 /home/steam/linux32/steamcmd \
  +@sSteamCmdForcePlatformType windows +force_install_dir "$server" +login anonymous +app_update 1829350 validate +quit
echo "steam_appid: $(cat "$server/steam_appid.txt")"
echo " "

mkdir "$data/Settings" 2>/dev/null
if [ ! -f "$data/Settings/ServerGameSettings.json" ]; then
	echo "$data/Settings/ServerGameSettings.json not found. Copying default file."
	cp "$server/VRisingServer_Data/StreamingAssets/Settings/ServerGameSettings.json" "$data/Settings/" 2>&1
fi
if [ ! -f "$data/Settings/ServerHostSettings.json" ]; then
	echo "$data/Settings/ServerHostSettings.json not found. Copying default file."
	cp "$server/VRisingServer_Data/StreamingAssets/Settings/ServerHostSettings.json" "$data/Settings/" 2>&1
fi

# Check if we have proper read/write permissions
if [ ! -r "$server" ] || [ ! -w "$server" ]; then
    echo "ERROR: I do not have read/write permissions to $server! Please run "chown -R ${UID}:${GID} $server" on host machine, then try again."
    exit 1
fi

echo "Starting V Rising Dedicated Server"

if [ -f "/tmp/.X0-lock" ]; then
	echo "Trying to remove /tmp/.X0-lock"
	rm /tmp/.X0-lock 2>&1
fi

echo " "
echo "Starting Xvfb"
Xvfb :0 -screen 0 1024x768x16 &
echo "Launching wine64 V Rising"
echo " "

DISPLAY=:0.0 wine64 "$server/VRisingServer.exe" -persistentDataPath $data -logFile "/dev/stdout" 2>&1 &
# Gets the PID of the last command
ServerPID=$!

wait $ServerPID
