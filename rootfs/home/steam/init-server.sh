#!/bin/bash

server=/vrising/server
data=/vrising/data

# check user
if [ $(id -u) -eq 0 ]; then
	echo "WARNING: Run steamcmd with root user is a security risk. see: https://developer.valvesoftware.com/wiki/SteamCMD" >&2
	echo "TIP: This image provides steam user with uid($(id steam -u)) and gid($(id steam -g)) as default"
fi

# Check if we have proper read/write permissions
if [ ! -r "$server" ] || [ ! -w "$server" ]; then
    echo "ERROR: I do not have read/write permissions to $server! Please run "chown -R $(id -u):$(id -g) $server" on host machine, then try again." >&2
    exit 1
fi

term_handler() {
	echo "Shutting down Server"

	PID=$(pgrep -of "/usr/local/bin/wine64 $server/VRisingServer.exe")
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
echo "Updating SteamCMD files..."
echo " "
export LD_LIBRARY_PATH="/home/steam/linux32:"
status_steamcmd=1

while [ $status_steamcmd -ne 0 ]; do
	box86 /home/steam/linux32/steamcmd +quit
	status_steamcmd=$?
done
echo " "
echo "Updating V-Rising Dedicated Server files..."
echo " "
box86 /home/steam/linux32/steamcmd +@sSteamCmdForcePlatformType windows +force_install_dir "$server" +login anonymous +app_update 1829350 validate +quit
echo "steam_appid: $(cat "$server/steam_appid.txt")"
echo " "

mkdir -p "$data/Settings"

echo "Starting V Rising Dedicated Server"

if [ -f "/tmp/.X0-lock" ]; then
	echo "Trying to remove /tmp/.X0-lock"
	rm -f /tmp/.X0-lock
fi

echo " "
echo "Starting Xvfb"
Xvfb :0 -screen 0 1024x768x16 &
echo "Launching wine64 V Rising"
echo " "

logfile="$(date +%s)-VRisingServer.log"
if [ ! -f "/tmp/$logfile" ]; then
	echo "Creating /tmp/$logfile"
	touch "/tmp/$logfile"
fi

DISPLAY=:0.0 wine64 "$server/VRisingServer.exe" -persistentDataPath $data -logFile "/tmp/$logfile" 2>&1 &
# Gets the PID of the last command
ServerPID=$!

tail -n 0 -f "/tmp/$logfile" &
wait $ServerPID
