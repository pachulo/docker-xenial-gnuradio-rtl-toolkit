#!/usr/bin/env bash

echo "Starting..."

# Audio support
#  Find a free port for pulseaudio
read LOWERPORT UPPERPORT < /proc/sys/net/ipv4/ip_local_port_range
while : ; do
  PULSE_PORT="`shuf -i $LOWERPORT-$UPPERPORT -n 1`"
  ss -lpn | grep -q ":$PULSE_PORT " || break
done
#  Get Docker daemon IP address
DOCKER_DAEMON_IP_WITH_MASK="`ip -4 -o a | grep docker0 | awk '{print $4}'`"
DOCKER_DAEMON_IP="`echo $DOCKER_DAEMON_IP_WITH_MASK | awk -F/ '{print $1}'`"
#  Load pulseaudio tcp module with this parameters
PULSE_MODULE_ID=$(pactl load-module module-native-protocol-tcp port=$PULSE_PORT auth-ip-acl=$DOCKER_DAEMON_IP_WITH_MASK)

# Video support
XAUTH=/tmp/.docker.xauth
touch $XAUTH
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -

# Launch container
docker run \
    -v $XAUTH:$XAUTH \
    -e XAUTHORITY=$XAUTH \
    -e DISPLAY \
    --device=/dev/dri/card0 \
    --device=/dev/bus/usb/002 \
    --net=host \
    -e PULSE_SERVER=tcp:$DOCKER_DAEMON_IP:$PULSE_PORT \
    --rm \
    -it xenial-gnuradio-rtl-toolkit:1.0

# Unload the pulseaudio module
pactl unload-module $PULSE_MODULE_ID
