# simonkeyd/wireguard-client

Is a docker image enabling one to easily connect to its WireGuard VPN. This image features the following:
* Standard wireguard config pass
* Local network routing
* Non-VPN traffic drop/block
* Auto-exit when tunnel is down

[WireGuard®](https://www.wireguard.com/) is an extremely simple yet fast and modern VPN that utilizes state-of-the-art cryptography. It aims to be faster, simpler, leaner, and more useful than IPsec, while avoiding the massive headache. It intends to be considerably more performant than OpenVPN. WireGuard is designed as a general purpose VPN for running on embedded interfaces and super computers alike, fit for many different circumstances. Initially released for the Linux kernel, it is now cross-platform (Windows, macOS, BSD, iOS, Android) and widely deployable. It is currently under heavy development, but already it might be regarded as the most secure, easiest to use, and simplest VPN solution in the industry.

[![wireguard](https://www.wireguard.com/img/wireguard.svg)](https://www.wireguard.com/)

## Supported Architecture
| Architecture | Available | Tested |
| :----: | :----: | ---- |
| amd64 | :heavy_check_mark: | :heavy_check_mark: |
| arm/v7 | :heavy_check_mark: | :x: |
| arm64/v8 | :heavy_check_mark: | :x: |

## Application Setup
During container start, it will first check if the wireguard module is already installed and loaded. Kernels newer than 5.6 generally have the wireguard module built-in (along with some older custom kernels). However, the module may not be enabled. Make sure it is enabled prior to starting the container.

If the kernel is not built-in, or installed on host, the container will check if the kernel headers are present (in `/usr/src`) and exit out if it is not the case.

If you're on a debian/ubuntu based host with a custom or downstream distro provided kernel (ie. Pop!_OS), the container won't be able to install the kernel headers from the regular ubuntu and debian repos. In those cases, you can try installing the headers on the host via `sudo apt install linux-headers-$(uname -r)` (if distro version) and then add a volume mapping for `/usr/src:/usr/src`, or if custom built, map the location of the existing headers to allow the container to use host installed headers to build the kernel module (tested successful on Pop!_OS, ymmv).

## Configuration
Drop your client conf into the config folder as `/config/wg0.conf` and start the container.

If you get IPv6 related errors in the log and connection cannot be established, edit the `AllowedIPs` line in your peer/client wg0.conf to include only `0.0.0.0/0` and not `::/0`; and restart the container.

Set `LOCAL_NETWORK` to allow traffic to be routed back to your local network. Expects a string (eg. `-e LOCAL_NETWORK='10.0.10.0/24'`).

## Usage
Here are some example snippets to help you get started creating a container.

### docker-compose (recommended)

```yaml
---
version: "2.1"
services:
  wireguard:
    image: simonkeyd/wireguard-client
    container_name: wireguard-client
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - LOCAL_NETWORK=192.168.1.0/24
      - PUID=1000
      - PGID=1000
    volumes:
      - /path/to/appdata/config:/config
      - /lib/modules:/lib/modules
      - /usr/src:/usr/src
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
```

### docker cli

```bash
docker run -d \
  --name=wireguard-client \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e LOCAL_NETWORK=192.168.1.0/24 \
  -e PUID=1000 \
  -e PGID=1000 \
  -v /path/to/appdata/config:/config \
  -v /lib/modules:/lib/modules \
  -v /usr/src:/usr/src \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  simonkeyd/wireguard-client
```

## Parameters
Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| :----: | --- |
| `-e LOCAL_NETWORK=192.168.1.0/24` | CIDR notation of your network IP address. Used to reroute packets to it instead of sending them to the VPN interface |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-v /config` | Contains all relevant configuration files. |
| `-v /lib/modules` | Maps host's modules folder. |
| `-v /user/src` | Maps host's src folder. |
| `--sysctl=` | Required for client mode. |

## Forcing traffic through VPN from another container
The following example will start a dummy container ensuring that its traffic is routed through wireguard-client container.
``` 
docker run -it
  --net=container:wireguard-client
  --entrypoint /bin/sh
  mwendler/wget
```

### Portainer notice

This image utilises `cap_add` or `sysctl` to work properly. This is not implemented properly in some versions of Portainer, thus this image may not work if deployed through Portainer.

## User / Group Identifiers

When using volumes (`-v` flags) permissions issues can arise between the host OS and the container, we avoid this issue by allowing you to specify the user `PUID` and group `PGID`.

Ensure any volume directories on the host are owned by the same user you specify and any permissions issues will vanish like magic.

In this instance `PUID=1000` and `PGID=1000`, to find yours use `id user` as below:

```bash
  $ id username
    uid=1000(dockeruser) gid=1000(dockergroup) groups=1000(dockergroup)
```

## Support Info

* Shell access whilst the container is running: `docker exec -it wireguard-client /bin/bash`
* To monitor the logs of the container in realtime: `docker logs -f wireguard-client`

## Updating Info

Most of our images are static, versioned, and require an image update and container recreation to update the app inside. With some exceptions (ie. nextcloud, plex), we do not recommend or support updating apps inside the container. Please consult the [Application Setup](#application-setup) section above to see if it is recommended for the image.

Below are the instructions for updating containers:

### Via Docker Compose

* Update all images: `docker-compose pull`
  * or update a single image: `docker-compose pull wireguard-client`
* Let compose update all containers as necessary: `docker-compose up -d`
  * or update a single container: `docker-compose up -d wireguard-client`
* You can also remove the old dangling images: `docker image prune`

### Via Docker Run

* Update the image: `docker pull lscr.io/linuxserver/wireguard-client:latest`
* Stop the running container: `docker stop wireguard-client`
* Delete the container: `docker rm wireguard-client`
* Recreate a new container with the same docker run parameters as instructed above (if mapped correctly to a host folder, your `/config` folder and settings will be preserved)
* You can also remove the old dangling images: `docker image prune`

### Via Watchtower auto-updater (only use if you don't remember the original parameters)

* Pull the latest image at its tag and replace it with the same env variables in one run:

  ```bash
  docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --run-once wireguard-client
  ```

* You can also remove the old dangling images: `docker image prune`

**Note:** We do not endorse the use of Watchtower as a solution to automated updates of existing Docker containers. In fact we generally discourage automated updates. However, this is a useful tool for one-time manual updates of containers where you have forgotten the original parameters. In the long term, we highly recommend using [Docker Compose](https://docs.linuxserver.io/general/docker-compose).

## Building locally

If you want to make local modifications to these images for development purposes or just to customize the logic:

```bash
docker build . \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VERSION=1.0.0 \
  -t wireguard-client
```
