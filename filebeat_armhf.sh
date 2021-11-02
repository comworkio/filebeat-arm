#!/usr/bin/env bash

# v1.2 / 2021-05-29 / Jan Schumacher / mail@jschumacher.info
# https://jschumacher.info/2021/03/up-to-date-filebeat-for-32bit-raspbian-armhf/
#
# v1.2: shellcheck'd, fixing variable double quoting. Using "awk 'FNR <= 1'" instead of "head -n 1" to avoid PIPEFAIL and 141 error.
# v1.1: Removing realtive paths, fixing dpkg-deb repackage method, updating help text, typos.

set -Eeuo pipefail
#set -Eeu
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] 

Non-interactive script for repackaging latest filebeat arm64 .deb files for 32 bit Raspbian.
Requires core-utils with (some) POSIX compliance, dpkg, md5sum, wget, curl, git. Tested with Ubuntu 20.10 and Debian 10.
Script will also download and extract the latest golang release under INSTALL_DIR 
and use it's binary for compiling, rather than using any potentially existing global go installation.
Everything is placed in ./filebeat_armhf.
This *should* continue to function as long as download links for golang and filebeat don't change.

Inspired by:
https://betterdev.blog/minimal-safe-bash-script-template
https://gist.github.com/m-radzikowski/53e0b39e9a59a1518990e76c2bff8038
https://gist.github.com/Zate/b3c8e18cbb2bbac2976d79525d95f893

Why no official arm builds?
https://github.com/elastic/beats/issues/9442

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
--no-color      Print all output without colors
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  msg ""
  msg "${GREEN} ### Cleaning up files ${NOFORMAT}"
  msg ""
  rm -rf "$INSTALL_DIR"/armhf
  rm -rf "$INSTALL_DIR"/go
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' 
  else
    NOFORMAT='' RED='' GREEN='' 
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  param=''

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  return 0
}

parse_params "$@"
setup_colors

INSTALL_DIR=./filebeat_armhf
GO_BINARY=$INSTALL_DIR/go/bin/go

if [ ! -d "$INSTALL_DIR" ]; then
  mkdir -p "$INSTALL_DIR"
fi

msg ""
msg "${GREEN} ### Working dir: $INSTALL_DIR ${NOFORMAT}"

setup_local_go() {
  GO_DL_SITE=https://golang.org
  GO_DL_PATH_URL="$(wget -qO- "$GO_DL_SITE"/dl/ | grep -oP '\/dl\/go([0-9\.]+)\.linux-amd64\.tar\.gz' | awk 'FNR <= 1')" 
  GO_LATEST="$(echo "$GO_DL_PATH_URL" | grep -oP 'go[0-9\.]+' | grep -oP '[0-9\.]+' | head -c -2 )"
  msg ""
  msg "${GREEN} ### Downloading latest Go for amd64: ${GO_LATEST} ${NOFORMAT}"
  msg ""
  wget --no-clobber --continue "$GO_DL_SITE""$GO_DL_PATH_URL" -P "$INSTALL_DIR"
  GO_LATEST_FILE="$(find "$INSTALL_DIR" -name "go$GO_LATEST*" -type f -printf "%f\n" | awk 'FNR <= 1')"
  msg ""
  msg "${GREEN} ### file downloaded: ${GO_LATEST_FILE} ${NOFORMAT}"
  msg ""
  tar -xzf "$INSTALL_DIR"/"$GO_LATEST_FILE" -C "$INSTALL_DIR"
  $GO_BINARY version
}

get_latest_beats() {
  BEATS_LATEST="$(curl --silent "https://api.github.com/repos/elastic/beats/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")'  | sed 's/v//')"
  msg ""
  msg "${GREEN} ### Downloading latest filebeat deb file for arm64: ${BEATS_LATEST} ${NOFORMAT}"
  msg ""
  wget --no-clobber --continue https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-"$BEATS_LATEST"-arm64.deb -P "$INSTALL_DIR"
  BEATS_LATEST_ARM64="$(find "$INSTALL_DIR" -name "filebeat-$BEATS_LATEST*" -type f -printf "%f\n" | awk 'FNR <= 1')"
  msg ""
  msg "${GREEN} ### file downloaded: ${BEATS_LATEST_ARM64} ${NOFORMAT}"
}

build_armhf_binary() {
  msg ""
  msg "${GREEN} ### Cloning from github.com/elastic/beats.git ${NOFORMAT}"
  msg ""
  mkdir -p "$INSTALL_DIR"/go/src/github.com/elastic ; cd "$INSTALL_DIR"/go/src/github.com/elastic
  git clone https://github.com/elastic/beats.git ; cd beats/filebeat
  git config advice.detachedHead false
  git checkout v"$BEATS_LATEST"
  msg ""
  msg "${GREEN} ### Building 32 bit arm binary for filebeat ... ${NOFORMAT}"
  GOARCH=arm $GO_BINARY build
  msg ""
  msg "${GREEN} ### Binary ready: ${NOFORMAT}"
  FILEBEAT_BINARY="$(file filebeat)"
  msg "$FILEBEAT_BINARY"
  msg ""
}

repackage_beats_deb() {
  msg ""
  msg "${GREEN} ### Repackaging $BEATS_LATEST_ARM64 file"
  msg " ### Removing original binary for filebeat-god, replacing binary for filebeat"
  msg " ### Updating control and md5sums files ${NOFORMAT}"
  mkdir "$INSTALL_DIR"/armhf
  dpkg-deb -x "$INSTALL_DIR"/"$BEATS_LATEST_ARM64" "$INSTALL_DIR"/armhf/
  dpkg-deb -e "$INSTALL_DIR"/"$BEATS_LATEST_ARM64" "$INSTALL_DIR"/armhf/DEBIAN
  rm "$INSTALL_DIR"/armhf/usr/share/filebeat/bin/filebeat
  rm "$INSTALL_DIR"/armhf/usr/share/filebeat/bin/filebeat-god
  cp "$INSTALL_DIR"/go/src/github.com/elastic/beats/filebeat/filebeat "$INSTALL_DIR"/armhf/usr/share/filebeat/bin/
  FILEBEAT_MD5="$(md5sum "$INSTALL_DIR"/armhf/usr/share/filebeat/bin/filebeat | awk '{print $1}')"
  sed -i 's/arm64/armhf/g' "$INSTALL_DIR"/armhf/DEBIAN/control
  sed -i '/filebeat-god/d' "$INSTALL_DIR"/armhf/DEBIAN/md5sums
  sed -i "s/.*usr\/share\/filebeat\/bin\/filebeat.*/$FILEBEAT_MD5  usr\/share\/filebeat\/bin\/filebeat/g" "$INSTALL_DIR"/armhf/DEBIAN/md5sums
  msg ""
  msg "${GREEN} ### Building new armhf deb file ${NOFORMAT}"
  msg ""
  cd "$INSTALL_DIR" ; dpkg-deb --root-owner-group --build armhf filebeat-"$BEATS_LATEST"-armhf.deb
  msg ""
  msg "${RED} ### Ready: $INSTALL_DIR/filebeat-$BEATS_LATEST-armhf.deb  ${NOFORMAT}"
  msg ""
  msg "${GREEN} ### Deploy on your Raspbian RPi with: 'dpkg -i filebeat-$BEATS_LATEST-armhf.deb ${NOFORMAT}"
}

setup_local_go
get_latest_beats
build_armhf_binary
repackage_beats_deb
