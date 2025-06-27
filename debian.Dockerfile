ARG debian_version=bookworm

FROM debian:${debian_version}-slim

ENV DEBIAN_FRONTEND="noninteractive"

LABEL maintainer="joaop221"

ARG debian_version=bookworm

# Install libraries needed to run box and v-rising
# - `cabextract` is needed by winetricks to install most libraries
# - `xvfb` is needed in wine to spawn display window because some Windows program can't run without it (using `xvfb-run`)
#   If you are sure you don't need it, feel free to remove
# reconfigure locales
# Install box64 and box86
RUN set -eux; \
 dpkg --add-architecture armhf && dpkg --add-architecture i386 && dpkg --add-architecture amd64; \
    apt-get update && apt-get install -y --no-install-recommends --no-install-suggests \
    p7zip-full wget ca-certificates cabextract xvfb locales procps netcat-traditional winbind gpg \
    libc6:armhf libc6:arm64 libc6:i386 libc6:amd64 libxi6:arm64 libxinerama1:arm64 \
    libxcursor1:arm64 libxcomposite1:arm64 libvulkan1:arm64; \
 locale-gen en_US.UTF-8 && dpkg-reconfigure locales; \
 wget -qO- "https://pi-apps-coders.github.io/box64-debs/KEY.gpg" | gpg --dearmor -o /usr/share/keyrings/box64-archive-keyring.gpg; \
 wget -qO- "https://pi-apps-coders.github.io/box86-debs/KEY.gpg" | gpg --dearmor -o /usr/share/keyrings/box86-archive-keyring.gpg; \
 wget -qO- "https://dl.winehq.org/wine-builds/winehq.key" | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key; \
 wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/${debian_version}/winehq-${debian_version}.sources; \
 echo "deb [signed-by=/usr/share/keyrings/box64-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box64-debs/debian ./" | tee /etc/apt/sources.list.d/box64.list; \
 echo "deb [signed-by=/usr/share/keyrings/box86-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box86-debs/debian ./" | tee /etc/apt/sources.list.d/box86.list; \
 apt-get update && apt-get install -y --install-recommends --no-install-suggests box64-rpi4arm64 box86-rpi4arm64:armhf \
    wine-stable-amd64 wine-stable-i386:i386 wine-stable:amd64 winehq-stable; \
 apt-get -y autoremove; \
 apt-get clean autoclean; \
 rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists

ENV LANG='en_US.UTF-8'
ENV LANGUAGE='en_US:en'

ENV BOX86_PATH=/opt/wine-stable/bin/
ENV BOX86_LD_LIBRARY_PATH=/opt/wine-stable/lib/wine/i386-unix/:/lib/i386-linux-gnu:/lib/aarch64-linux-gnu/
ENV BOX64_PATH=/opt/wine-stable/bin/
ENV BOX64_LD_LIBRARY_PATH=/opt/wine-stable/lib/i386-unix/:/opt/wine-stable/lib64/wine/x86_64-unix/:/lib/i386-linux-gnu/:/lib/x86_64-linux-gnu:/lib/aarch64-linux-gnu/

ENV WINEARCH=win64 WINEPREFIX=/home/steam/.wine
ENV WINEDLLOVERRIDES="mscoree,mshtml="

ENV DISPLAY=:0
ENV DISPLAY_WIDTH=1024
ENV DISPLAY_HEIGHT=768
ENV DISPLAY_DEPTH=16

ENV AUTO_UPDATE=1
ENV XVFB=1

ARG UID=1001
ARG GID=1001
 
# Setup steam user
RUN set -eux; \
 groupadd -g ${GID} steam && useradd -u ${UID} -m steam -g steam; \
 wget -qO - "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam; \
 chown -R steam:steam /home/steam

# install winetricks give permissions to execute custom wine commands
RUN set -eux; \
 wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; \
 chmod +x winetricks; \
 mv winetricks /usr/local/bin/

VOLUME ["/vrising/server", "/vrising/data"]

USER steam
WORKDIR /home/steam

# Define the health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10m \
    CMD /home/steam/healthz.sh

# Run steamcmd to update the server
RUN set -ux; \
    status_steamcmd=1; \
    while [ $status_steamcmd -ne 0 ]; do \
        /home/steam/steamcmd.sh +quit; \
	    status_steamcmd=$?; \
    done

# Run boot wine and tricks install 
RUN set -eux; \
    /opt/wine-stable/bin/wine64 wineboot; \
    BOX86_NOBANNER=1 WINE=/opt/wine-stable/bin/wine64 winetricks -q arch=64 comctl32ocx comdlg32ocx dotnet45 corefonts d3dx10 d3dx9_36 dxvk

ADD --chown=steam:steam scripts /home/steam/

RUN set -eux; \
    chmod +x /home/steam/init-server.sh /home/steam/healthz.sh

# Run it
CMD ["/home/steam/init-server.sh"] 