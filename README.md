# Repackage filebeat ARM

Repackage filebeat deb package for armhf (32 bits) architecture.

Usefull for raspberrypi that are still running on armhf raspberrypi OS.

## Table of content

[[_TOC_]]

## Source

Based on this [gist](https://gist.github.com/lazywebm/63ce309cffe6483bb5fc2d8a9e7cf50b).

You'll see more details [here](https://jschumacher.info/2021/03/up-to-date-filebeat-for-32bit-raspbian-armhf/)

## Git repositories

* Main repo: https://gitlab.comwork.io/oss/filebeat-arm
* Github mirror: https://github.com/idrissneumann/filebeat-arm.git
* Gitlab mirror: https://gitlab.com/ineumann/filebeat-arm.git
* Bitbucket mirror: https://bitbucket.org/idrissneumann/filebeat-arm.git
* Froggit mirror: https://lab.frogg.it/ineumann/filebeat-arm.git

## Builds

Builded deb package for armhf are available [here](./filebeat_armhf)

## Getting started

Run those command from a x86 host based on Ubuntu or Debian:

```shell
$ git clone "https://gitlab.comwork.io/oss/elasticstack/filebeat-arm"
$ ./filebeat_armhf.sh
```

Then you'll just have to pick the armhf package generated in `./filebeat_armhf` subdirectory.
