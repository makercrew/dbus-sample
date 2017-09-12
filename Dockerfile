#########
# Created and copyrighted by Zachary J. Fields. Offered as open source under the MIT License (MIT).
#
# Related Blog Post: https://makercrew.com/404
#########

# Base Image
FROM alpine:latest

WORKDIR /root/

# Add Required Packages [Layer 1]
RUN apk update && \
    apk add \
      ca-certificates \
      dbus \
      dbus-dev \
      g++ \
      git

# Download Sources [Layer 2]
RUN cd ~ && \
    git clone https://github.com/makercrew/dbus-sample.git --recursive && \
    cd dbus-sample/ && \
    g++ dbus.cpp -std=c++0x $(pkg-config dbus-1 --cflags) -ldbus-1 -Werror -Wall -Wextra

# Verify Build and Install
CMD dbus-daemon --system --nofork
