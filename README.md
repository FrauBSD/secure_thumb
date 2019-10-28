[//]: # ($FrauBSD: //github.com/FrauBSD/secure_thumb/README.md 2019-10-28 13:53:36 +0000 freebsdfrau $)

# Welcome to [FrauBSD.org/secure\_thumb](https://fraubsd.org/secure_thumb)!

[GELI](https://www.freebsd.org/cgi/man.cgi?query=geli) encrypted
thumb drives for FreeBSD.

## Foreword

The following is required before using `git commit` in this project.

> `$ .git-hooks/install.sh`

This will ensure the FrauBSD keyword is expanded/updated for each commit.

# Setup

## Build image (requires `sudo` access)

> `$ make`

## Deploy image to physical hardware (requires `sudo` access)

> 1. `$ make deploy`
> 2. Insert thumb drive and press `ENTER`

## Install shell additions (some manual steps required)

> 1. `$ make install`
> 2. Follow steps to finalize system setup

# Creating SSH keys (requires `sudo` access)

> 1. Connect USB thumb drive to host
> 2. `$ openkey`
> 3. `$ cd /mnt/keys`
> 4. `$ make`
> 5. `$ cd -`
> 6. `$ closekey -e`

## Loading keys and ejecting the thumb drive (requires `sudo access`)

> 1. `$ loadkeys`
> 2. **NOTE:** By default, keys are loaded for 1800s (30m)
> 3. `$ closekey -e`

## Load keys for an extended period (requires `sudo access`)

> 1. `$ loadkeys -t13h`
> 2. `$ closekey -e`
> 3. **NOTE:** Keys will remain usable via ssh-agent for 13h

# Additional Features

## Optionally expand thumb drive to take up free space (requires `sudo`)

> `$ make expand`

## Usage statement

> `$ make help`

## Help on shell additions

> 1. `$ openkey -h`
> 2. `$ closekey -h`
> 3. `$ loadkeys -h`
> 4. `$ unloadkeys -h`

## Sync files created on the thumb drive to the local image

> `$ make synctoimg`

## Sync files created in the image to the thumb drive

> `$ make synctousb`

## Resize the image to 1GB to increase free space

> `$ make IMGSIZE=1024 resize`

## Load keys and then eject the thumb drive

> `$ loadkeys -e`
