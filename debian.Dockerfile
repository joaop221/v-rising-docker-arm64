ARG debian_version=bookworm

FROM debian:${debian_version}-slim AS base-builder

ENV DEBIAN_FRONTEND="noninteractive"

WORKDIR /root

# install required packages, build box86/box64 and download steam cmd
RUN set -eux; \
 dpkg --add-architecture armhf && apt-get update && apt-get install -y --no-install-recommends --no-install-suggests \
    git cmake python3 build-essential gcc-arm-linux-gnueabihf libc6-dev-armhf-cross libc6:armhf libstdc++6:armhf ca-certificates

FROM base-builder AS box86-builder
 
RUN set -eux; \
 git clone https://github.com/ptitSeb/box86 \
    && mkdir box86/build \
    && cd box86/build \
    && cmake .. -DRPI4ARM64=1 -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    && make -j$(nproc) \
    && make install DESTDIR=/box

FROM base-builder AS box64-builder

RUN set -eux; \
 git clone https://github.com/ptitSeb/box64 \
    && mkdir box64/build \
    && cd box64/build \
    && cmake .. -DRPI4ARM64=1 -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    && make -j$(nproc) \
    && make install DESTDIR=/box

FROM debian:${debian_version}-slim

ENV DEBIAN_FRONTEND="noninteractive"

LABEL maintainer="joaop221"

# Install libraries needed to run box and v-rising
# - `cabextract` is needed by winetricks to install most libraries
# - `xvfb` is needed in wine to spawn display window because some Windows program can't run without it (using `xvfb-run`)
#   If you are sure you don't need it, feel free to remove
# - dependencies packages specified by box64/box86 docs
RUN set -eux; \
 dpkg --add-architecture armhf && dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends --no-install-suggests \
    wget ca-certificates cabextract xvfb locales procps netcat-traditional libc6:i386 \
    libasound2:armhf libc6:armhf libglib2.0-0:armhf libgphoto2-6:armhf libgphoto2-port12:armhf \
    libgstreamer-plugins-base1.0-0:armhf libgstreamer1.0-0:armhf libldap-2.4-2:armhf libopenal1:armhf libpcap0.8:armhf \
    libpulse0:armhf libsane1:armhf libudev1:armhf libusb-1.0-0:armhf libvkd3d1:armhf libx11-6:armhf libxext6:armhf \
    libasound2-plugins:armhf ocl-icd-libopencl1:armhf libncurses6:armhf libncurses5:armhf libcap2-bin:armhf libcups2:armhf \
    libdbus-1-3:armhf libfontconfig1:armhf libfreetype6:armhf libglu1-mesa:armhf libglu1:armhf libgnutls30:armhf \
    libgssapi-krb5-2:armhf libkrb5-3:armhf libodbc1:armhf libosmesa6:armhf libsdl2-2.0-0:armhf libv4l-0:armhf \
    libxcomposite1:armhf libxcursor1:armhf libxfixes3:armhf libxi6:armhf libxinerama1:armhf libxrandr2:armhf \
    libxrender1:armhf libxxf86vm1 libcap2-bin:armhf \
    libstdc++6:armhf libasound2-plugins:arm64 libasound2:arm64 libc6:arm64 libldap-2.4-2:arm64 libopenal1:arm64 \
    libcapi20-3:arm64 libcups2:arm64 libdbus-1-3:arm64 libfontconfig1:arm64 libfreetype6:arm64 libglib2.0-0:arm64 \
    libglu1-mesa:arm64 libgnutls30:arm64 libgphoto2-6:arm64 libgphoto2-port12:arm64 libgsm1:arm64 libvkd3d1:arm64 \
    libgssapi-krb5-2:arm64 libgstreamer-plugins-base1.0-0:arm64 libgstreamer1.0-0:arm64 libjpeg62-turbo:arm64 \
    libkrb5-3:arm64 libncurses6:arm64 libncurses5:arm64 libodbc1:arm64 libosmesa6:arm64 libpcap0.8:arm64 \
    libpulse0:arm64 libsane1:arm64 libsdl2-2.0-0:arm64 libtiff6:arm64 libudev1:arm64 libusb-1.0-0:arm64 \
    libv4l-0:arm64 libx11-6:arm64 libxcomposite1:arm64 libxcursor1:arm64 libxext6:arm64 libxfixes3:arm64 \
    libxi6:arm64 libxinerama1:arm64 libxrandr2:arm64 libxrender1:arm64 libxslt1.1:arm64 libxxf86vm1:arm64 \
    ocl-icd-libopencl1:arm64 libpng16-16:arm64; \
 apt-get -y autoremove; \
 apt-get clean autoclean; \
 rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists

RUN set -eux; \
 locale-gen en_US.UTF-8 && dpkg-reconfigure locales
ENV LANG='en_US.UTF-8'
ENV LANGUAGE='en_US:en'

ARG UID=1001
ARG GID=1001

ADD rootfs /
 
# Install packages and Setup steam user
RUN set -eux; \
 groupadd -g ${GID} steam && useradd -u ${UID} -m steam -g steam; \
 chmod 750 /home/steam/healthz.sh /home/steam/init-server.sh; \
 wget -qO - "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam; \
 chown -R steam:steam /home/steam

ARG debian_version=bookworm
# see: https://dl.winehq.org/wine-builds/debian/dists/<debian_version>/main/binary-amd64/ - e.g.:
# - https://dl.winehq.org/wine-builds/debian/dists/bookworm/main/binary-amd64/
# - https://dl.winehq.org/wine-builds/debian/dists/bullseye/main/binary-amd64/
ARG wine_version="9.0.0.0"
# devel, staging, or stable
ARG wine_branch="stable"
# : -1 (some wine .deb files have -1 tag on the end and some don't)
ARG wine_tag="-1"

# - wine64 and winetricks - ref https://github.com/ptitSeb/box64/blob/main/docs/X64WINE.md#examples for win64
RUN set -eux; \
 LNKA="https://dl.winehq.org/wine-builds/debian/dists/${debian_version}/main/binary-amd64/"; \
 DEB_A1="wine-${wine_branch}-amd64_${wine_version}~${debian_version}${wine_tag}_amd64.deb"; \
 DEB_A2="wine-${wine_branch}_${wine_version}~${debian_version}${wine_tag}_amd64.deb"; \
 LNKB="https://dl.winehq.org/wine-builds/debian/dists/${debian_version}/main/binary-i386/"; \
 DEB_B1="wine-${wine_branch}-i386_${wine_version}~${debian_version}${wine_tag}_i386.deb"; \
 echo -e "Downloading wine . . ."; \
 wget -q ${LNKA}${DEB_A1}; \
 wget -q ${LNKA}${DEB_A2}; \
 wget -q ${LNKB}${DEB_B1}; \
 echo -e "Extracting wine . . ."; \
 dpkg-deb -x ${DEB_A1} wine-installer; \
 dpkg-deb -x ${DEB_A2} wine-installer; \
 dpkg-deb -x ${DEB_B1} wine-installer; \
 echo -e "Installing wine . . ."; \
 mv wine-installer/opt/wine* /home/steam/wine; \
 rm -rf ${DEB_A1} ${DEB_A2} ${DEB_B1}; \
 wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; \
 chmod +x winetricks; \
 mv winetricks /usr/local/bin/; \
 ln -s /home/steam/wine/bin/wineboot /usr/local/bin/wineboot; \
 ln -s /home/steam/wine/bin/winecfg /usr/local/bin/winecfg; \
 chmod +x /usr/local/bin/wine /usr/local/bin/wine64 /usr/local/bin/wineboot /usr/local/bin/winecfg /usr/local/bin/wineserver

# Copy compiled box86 binaries
COPY --from=box86-builder /box /
# Copy compiled box64 binaries
COPY --from=box64-builder /box /

VOLUME ["/vrising/server", "/vrising/data"]

USER steam
WORKDIR /home/steam

# run wineboot and winetricks install dotnet 4.8
RUN wine wineboot -i && wine64 wineboot -i && env WINEPREFIX=~/.wine64 WINE=~/wine/bin/wine64 winetricks -q arch=64 dotnet48

# Define the health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10m \
    CMD /home/steam/healthz.sh

# Run it
CMD ["/home/steam/init-server.sh"] 