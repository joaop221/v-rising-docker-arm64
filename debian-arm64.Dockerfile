FROM --platform=arm64 debian:bookworm-slim as build

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /root

# install required packages
RUN set -eux; \
 apt-get update && apt-get install -y --no-install-recommends --no-install-suggests \
    git cmake python3 build-essential ca-certificates wget software-properties-common

# Download steam cmd
RUN set -eux; \
 wget -qO - "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - \
 && chmod 750 ./steamcmd/steamcmd.sh

# Build box64
RUN set -eux; \
 git clone https://github.com/ptitSeb/box64 \
 && mkdir box64/build \
 && cd box64/build \
 && cmake .. -DRPI4ARM64=1 -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo \
 && make -j$(nproc) \
 && make install DESTDIR=/box

FROM --platform=arm64 debian:bookworm-slim

ENV DEBIAN_FRONTEND="noninteractive"

LABEL maintainer="joaop221"

ADD rootfs /

# Copy compiled box64 binaries
COPY --from=build /box /

# Install libraries needed to run box
# `cabextract` is needed by winetricks to install most libraries
# `xvfb` is needed in wine to spawn display window because some Windows program can't run without it (using `xvfb-run`)
# If you are sure you don't need it, feel free to remove
RUN set -eux \
 && apt-get update \
 && apt install -y wget cabextract xvfb \
 && apt-get -y autoremove \
 && apt-get clean autoclean \
 && rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists

#example: devel, staging, or stable (wine-staging 4.5+ requires libfaudio0:i386)
ARG wine_branch="stable"
# see: "https://www.winehq.org/news/"
ARG wine_version="7.0.2"
# supported: debian, ubuntu
ARG id="debian"
# dist names: (for debian): bullseye, buster, jessie, wheezy, ${VERSION_CODENAME}, etc 
ARG dist="bookworm"
# : -1 (some wine .deb files have -1 tag on the end and some don't)
ARG tag="-1"

# Install wine64 and winetricks - source code from https://github.com/ptitSeb/box64/blob/main/docs/X64WINE.md#examples for win
RUN set -eux; \
    LNKA="https://dl.winehq.org/wine-builds/${id}/dists/${dist}/main/binary-amd64/"; \
    DEB_A1="wine-${wine_branch}-amd64_${wine_version}~${dist}${tag}_amd64.deb"; \
    DEB_A2="wine-${wine_branch}_${wine_version}~${dist}${tag}_amd64.deb"; \
    DEB_A3="winehq-${wine_branch}_${wine_version}~${dist}${tag}_amd64.deb"; \
    echo -e "Downloading wine . . ."; \
    wget -q ${LNKA}${DEB_A1}; \
    wget -q ${LNKA}${DEB_A2}; \
    wget -q ${LNKB}${DEB_B1}; \
    echo -e "Extracting wine . . ."; \
    dpkg-deb -x ${DEB_A1} wine-installer; \
    dpkg-deb -x ${DEB_A2} wine-installer; \
    dpkg-deb -x ${DEB_B1} wine-installer; \
    echo -e "Installing wine . . ."; \
    mv wine-installer/opt/wine* ~/wine; \
    rm -rf ${DEB_A1} ${DEB_A2} ${DEB_B1}; \
    apt-get install -y \
        libasound2-plugins:arm64 libasound2:arm64 libc6:arm64 libcapi20-3:arm64 libcups2:arm64 libdbus-1-3:arm64 libfontconfig1:arm64 \
        libfreetype6:arm64 libglib2.0-0:arm64 libglu1-mesa:arm64 libgnutls30:arm64 libgphoto2-6:arm64 libgphoto2-port12:arm64 libgsm1:arm64 \
        libgssapi-krb5-2:arm64 libgstreamer-plugins-base1.0-0:arm64 libgstreamer1.0-0:arm64 libjpeg62-turbo:arm64 libkrb5-3:arm64 libncurses6:arm64 \
        libodbc1:arm64 libosmesa6:arm64 libpcap0.8:arm64 libpng16-16:arm64 libpulse0:arm64 libsane1:arm64 libsdl2-2.0-0:arm64 libtiff6:arm64 libudev1:arm64 \
        libusb-1.0-0:arm64 libv4l-0:arm64 libx11-6:arm64 libxcomposite1:arm64 libxcursor1:arm64 libxext6:arm64 libxfixes3:arm64 libxi6:arm64 libxinerama1:arm64 \
        libxrandr2:arm64 libxrender1:arm64 libxslt1.1:arm64 libxxf86vm1:arm64 ocl-icd-libopencl1:arm64; \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; \
    chmod +x winetricks; \
    mv winetricks /usr/local/bin/; \
    apt-get -y autoremove; \
    apt-get clean autoclean; \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists; \
    ln -s ~/wine/bin/wineboot /usr/local/bin/wineboot; \
    ln -s ~/wine/bin/winecfg /usr/local/bin/winecfg; \
    chmod +x /usr/local/bin/wine64 /usr/local/bin/wineboot /usr/local/bin/winecfg /usr/local/bin/wineserver
 
ARG UID=1001
ARG GID=1001
 
# Install packages and Setup steam user
RUN set -eux; \
    groupadd -g ${GID} steam && useradd -u ${UID} -m steam -g steam; \
    chmod 750 /home/stean/healthz.sh /home/stean/init-server.sh

# Copy steamcmd
COPY --from=build --chown=steam:steam /steamcmd /home/steam

VOLUME ["/vrising/server", "/vrising/data"]

USER steam
WORKDIR /home/steam

# Define the health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10m \
    CMD /home/steam/healthz.sh

# Run it
CMD ["./init-server.sh"] 