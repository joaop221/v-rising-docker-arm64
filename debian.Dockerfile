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
    && cmake .. -DRPI4ARM64=1 -DARM_DYNAREC=ON -DWOW64=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo \
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
    p7zip-full wget ca-certificates cabextract xvfb locales procps netcat-traditional winbind gpg libc6:i386 \
    libasound2:armhf libc6:armhf libglib2.0-0:armhf libgphoto2-6:armhf libgphoto2-port12:armhf libtalloc2:armhf \
    libgstreamer-plugins-base1.0-0:armhf libgstreamer1.0-0:armhf libldap-2.5-0:armhf libopenal1:armhf libpcap0.8:armhf \
    libpulse0:armhf libsane1:armhf libudev1:armhf libusb-1.0-0:armhf libvkd3d1:armhf libx11-6:armhf libxext6:armhf \
    libasound2-plugins:armhf ocl-icd-libopencl1:armhf libncurses6:armhf libncurses5:armhf libcap2-bin:armhf libcups2:armhf \
    libdbus-1-3:armhf libfontconfig1:armhf libfreetype6:armhf libglu1-mesa:armhf libglu1:armhf libgnutls30:armhf \
    libgssapi-krb5-2:armhf libkrb5-3:armhf libodbc1:armhf libosmesa6:armhf libsdl2-2.0-0:armhf libv4l-0:armhf \
    libxcomposite1:armhf libxcursor1:armhf libxfixes3:armhf libxi6:armhf libxinerama1:armhf libxrandr2:armhf libwbclient0:armhf \
    libxrender1:armhf libxxf86vm1:armhf libcap2-bin:armhf libsasl2-2:armhf libsasl2-modules-db:armhf libgtk-3-0:armhf \
    libstdc++6:armhf libgtk-3-common:armhf libcolord2:armhf libcairo2:armhf libcups2:armhf libnss-winbind:armhf \
    libasound2-plugins:arm64 libasound2:arm64 libc6:arm64 libldap-2.5-0:arm64 libopenal1:arm64 libtalloc2:arm64 \
    libcapi20-3:arm64 libcups2:arm64 libdbus-1-3:arm64 libfontconfig1:arm64 libfreetype6:arm64 libglib2.0-0:arm64 \
    libglu1-mesa:arm64 libgnutls30:arm64 libgphoto2-6:arm64 libgphoto2-port12:arm64 libgsm1:arm64 libvkd3d1:arm64 \
    libgssapi-krb5-2:arm64 libgstreamer-plugins-base1.0-0:arm64 libgstreamer1.0-0:arm64 libjpeg62-turbo:arm64 \
    libkrb5-3:arm64 libncurses6:arm64 libncurses5:arm64 libodbc1:arm64 libosmesa6:arm64 libpcap0.8:arm64 \
    libpulse0:arm64 libsane1:arm64 libsdl2-2.0-0:arm64 libtiff6:arm64 libudev1:arm64 libusb-1.0-0:arm64 libwbclient0:arm64 \
    libv4l-0:arm64 libx11-6:arm64 libxcomposite1:arm64 libxcursor1:arm64 libxext6:arm64 libxfixes3:arm64 \
    libxi6:arm64 libxinerama1:arm64 libxrandr2:arm64 libxrender1:arm64 libxslt1.1:arm64 libxxf86vm1:arm64 \
    ocl-icd-libopencl1:arm64 libpng16-16:arm64 libsasl2-2:arm64 libsasl2-modules-db:arm64 libgtk-3-0:arm64 \
    libgtk-3-common:arm64 libcolord2:arm64 libcairo2:arm64 libcups2:arm64 libnss-winbind:arm64; \
 apt-get -y autoremove; \
 apt-get clean autoclean; \
 rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists

RUN set -eux; \
 locale-gen en_US.UTF-8 && dpkg-reconfigure locales
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

# - wine64 and winetricks 
#   - ref https://github.com/ptitSeb/box64/blob/main/docs/X64WINE.md#examples for win64
#   - ref https://gitlab.winehq.org/wine/wine/-/wikis/Debian-Ubuntu
ARG debian_version=bookworm
# devel, staging, or stable
ARG wine_branch="stable"

RUN set -eux; \
 dpkg --add-architecture amd64 && \
 wget -O - https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key -; \
 wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/debian/dists/${debian_version}/winehq-${debian_version}.sources; \
 apt-get update && apt-get install -y --no-install-recommends --no-install-suggests wine-${wine_branch}; \
 apt-get -y autoremove; \
 apt-get clean autoclean; \
 rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists; \
 wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; \
 chmod +x winetricks; \
 mv winetricks /usr/local/bin/; \
 chmod +x /usr/local/bin/wine /usr/local/bin/wineboot /usr/local/bin/winecfg /usr/local/bin/wineserver

ENV WINE_BRANCH=${wine_branch}
ENV WINEPREFIX="/home/steam/.wine"
ENV WINEARCH="win64"

# Copy compiled box86 binaries
COPY --from=box86-builder /box /
# Copy compiled box64 binaries
COPY --from=box64-builder /box /

VOLUME ["/vrising/server", "/vrising/data"]

USER steam
WORKDIR /home/steam

# Define the health check
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10m \
    CMD /home/steam/healthz.sh

# Run wine boot and tricks install
RUN set -eux; \
    wine wineboot -i; \
    BOX86_NOBANNER=1 winetricks -q arch=64 comctl32ocx comdlg32ocx dotnet45

# Run it
CMD ["/home/steam/init-server.sh"] 