#!/bin/bash

set -eux

echo "Check game port availability"
nc -nzuv "127.0.0.1" ${VR_GAME_PORT:-"9876"}

echo "Check query port availability"
nc -nzuv "127.0.0.1" ${VR_QUERY_PORT:-"9877"}
