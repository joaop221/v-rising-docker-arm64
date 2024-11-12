# v-rising-docker-arm64

V Rising Dedicated Server inside Docker ARM64 container.

## Build image locally

To build this image you need an ARM64 System or enable multi-platform support in your container engine. To do so with docker read this: [Multi-platform images](https://docs.docker.com/build/building/multi-platform/).

With this setup done you can proceed to build:

```bash
docker buildx build --platform linux/arm64 -t v-rising-docker-arm64:local -f debian.Dockerfile . --load
```

> **About buildx:** `--load` will give you an option to load this image at your local images list: [docker builx build reference](https://docs.docker.com/reference/cli/docker/buildx/build/).

## Running image locally

To run this image you do not need to install V Rising at your system nor to setup game server externally of docker, but it's recommended to read the doc: [V Rising Dedicated Server Instructions](https://github.com/StunlockStudios/vrising-dedicated-server-instructions).

See the command (remember to enable multi-platform support or use a ARM64 system):

```bash
docker run -d --platform linux/arm64 \
    -p 9876:9876/udp \
    -p 9877:9877/udp \
    -v ./volumes/v-rising/data:/vrising/data \
    -v ./volumes/v-rising/server:/vrising/server \
    ghcr.io/joaop221/v-rising-docker-arm64:main
```

Keep in mind that you can include additional environment variables to configure the behavior of game, as described here: [V Rising Dedicated Server Instructions for v1.0.x](https://github.com/StunlockStudios/vrising-dedicated-server-instructions/blob/master/1.0.x/INSTRUCTIONS.md).

## Technical notes

To download the game we need to emulate [steamcmd](https://www.steamcmd.net/) architecture, this is made using [box86](https://github.com/ptitSeb/box86).

And to run V Rising Server we need another combination of packages [box64 + wine64](https://github.com/ptitSeb/box64?tab=readme-ov-file#notes-about-wine).

## Credits and Links

This image was based on implementation and docs available in:

- [V Rising Dedicated Server Instructions](https://github.com/StunlockStudios/vrising-dedicated-server-instructions);
- [TrueOsiris/docker-vrising](https://github.com/TrueOsiris/docker-vrising);
- [gogoout/vrising-arm64](https://github.com/gogoout/vrising-server-arm64).
