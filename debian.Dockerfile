ARG debian_version=bookworm

FROM debian:${debian_version}-slim

ENV DEBIAN_FRONTEND="noninteractive"

LABEL maintainer="joaop221"

# Install libraries needed to run box and v-rising
# - `cabextract` is needed by winetricks to install most libraries
# - `xvfb` is needed in wine to spawn display window because some Windows program can't run without it (using `xvfb-run`)
#   If you are sure you don't need it, feel free to remove
# reconfigure locales
# Install box64 and box86
RUN set -eux; \
 dpkg --add-architecture armhf && dpkg --add-architecture i386 && dpkg --add-architecture amd64; \
    apt-get update && apt-get install -y --no-install-recommends --no-install-suggests \
    p7zip-full wget ca-certificates cabextract xvfb locales procps netcat-traditional winbind gpg libc6:i386 \
    wine:amd64 wine32:i386 wine64:amd64 libwine:amd64 libwine:i386 fonts-wine:amd64; \
 locale-gen en_US.UTF-8 && dpkg-reconfigure locales; \
 wget -qO- "https://pi-apps-coders.github.io/box64-debs/KEY.gpg" | gpg --dearmor -o /usr/share/keyrings/box64-archive-keyring.gpg; \
 wget -qO- "https://pi-apps-coders.github.io/box86-debs/KEY.gpg" | gpg --dearmor -o /usr/share/keyrings/box86-archive-keyring.gpg; \
 echo "deb [signed-by=/usr/share/keyrings/box64-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box64-debs/debian ./" | tee /etc/apt/sources.list.d/box64.list; \
 echo "deb [signed-by=/usr/share/keyrings/box86-archive-keyring.gpg] https://Pi-Apps-Coders.github.io/box86-debs/debian ./" | tee /etc/apt/sources.list.d/box86.list; \
 apt-get update && apt-get install -y --no-install-recommends --no-install-suggests box64-generic-arm box86-generic-arm:armhf; \
 apt-get -y autoremove; \
 apt-get clean autoclean; \
 rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists

ENV LANG='en_US.UTF-8'
ENV LANGUAGE='en_US:en'

ENV DISPLAY=:0

ARG UID=1001
ARG GID=1001

ADD rootfs /
 
# Setup steam user
RUN set -eux; \
 groupadd -g ${GID} steam && useradd -u ${UID} -m steam -g steam; \
 chmod 750 /home/steam/healthz.sh /home/steam/init-server.sh; \
 wget -qO - "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam; \
 chown -R steam:steam /home/steam

# install winetricks give permissions to execute custom wine commands
RUN set -eux; \
 wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; \
 chmod +x winetricks; \
 mv winetricks /usr/local/bin/; \
 chmod +x /usr/local/bin/wine /usr/local/bin/wine64 /usr/local/bin/wineboot /usr/local/bin/winecfg /usr/local/bin/wineserver

VOLUME ["/vrising/server", "/vrising/data"]

USER steam
WORKDIR /home/steam

# Define the health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10m \
    CMD /home/steam/healthz.sh

# Run wine boot and tricks install
RUN set -eux; \
    wine wineboot -i; \
    wine64 wineboot -i; \
    winetricks -q arch=64 comctl32ocx comdlg32ocx dotnet45

# Run it
CMD ["/home/steam/init-server.sh"] 