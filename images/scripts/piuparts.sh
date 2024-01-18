#!/usr/bin/env bash
# -*- coding: utf-8 -*-

# Copyright salsa-ci-team and others
# SPDX-License-Identifier: FSFAP
# Copying and distribution of this file, with or without modification, are
# permitted in any medium without royalty provided the copyright notice and
# this notice are preserved. This file is offered as-is, without any warranty.

# shellcheck disable=SC1091
source /usr/local/bin/lib.sh

set -eu -o pipefail

cd "${INPUT_SOURCE_PATH}" || exit 1
create_user_for .

echo "::group::Fixup INPUT_* variables"
# Fixup INPUT_TESTBED
INPUT_TESTBED="${INPUT_TESTBED:-ghcr.io/${GITHUB_REPOSITORY_OWNER}/base:${INPUT_RELEASE}}"
# Fixup INPUT_ARGS
INPUT_ARGS="${INPUT_ARGS:-}"

while IFS='=' read -r -d '' name value; do
  case "${name}" in
  INPUT_*) echo "${name}=${value}";;
  esac
done < <(env -0)
echo "::endgroup::"

echo "::group::Docker info"
docker info
echo "::endgroup::"

CHROOT_PATH="/tmp/debian-chroot"
CONTAINER_ID=$(docker run --rm -d "${SALSA_CI_IMAGES_BASE}" sleep infinity)
docker exec ${CONTAINER_ID} bash -c "apt-get update && apt-get upgrade -y"
docker exec ${CONTAINER_ID} bash -c "apt-get install eatmydata -y"
mkdir -vp ${CHROOT_PATH}
docker export ${CONTAINER_ID} | tar -C ${CHROOT_PATH} -xf -
mknod -m 666 ${CHROOT_PATH}/dev/urandom c 1 9
mkdir -vp /srv/local-apt-repository/ && cp -av ${WORKING_DIR}/*.deb /srv/local-apt-repository/ && /usr/lib/local-apt-repository/rebuild
mkdir -vp ${CHROOT_PATH}/etc-target/apt/sources.list.d ${CHROOT_PATH}/etc-target/apt/preferences.d
cp -Hv /etc/apt/sources.list.d/local-apt-repository.list ${CHROOT_PATH}/etc-target/apt/sources.list.d/
cp -aTLv /etc/apt/preferences.d  ${CHROOT_PATH}/etc-target/apt/preferences.d
cp -aTLv /srv/local-apt-repository ${CHROOT_PATH}/srv/local-apt-repository
cp -aTLv /var/lib/local-apt-repository/ ${CHROOT_PATH}/var/lib/local-apt-repository/
test -n "${SALSA_CI_PIUPARTS_PRE_INSTALL_SCRIPT}" && cp -aTLv "${SALSA_CI_PIUPARTS_PRE_INSTALL_SCRIPT}" /etc/piuparts/scripts/pre_install_salsa_ci && chmod 755 /etc/piuparts/scripts/pre_install_salsa_ci
test -n "${SALSA_CI_PIUPARTS_POST_INSTALL_SCRIPT}" && cp -aTLv "${SALSA_CI_PIUPARTS_POST_INSTALL_SCRIPT}" /etc/piuparts/scripts/post_install_salsa_ci && chmod 755 /etc/piuparts/scripts/post_install_salsa_ci
add_extra_repository.sh -v -e "${SALSA_CI_EXTRA_REPOSITORY}"
      -k "${SALSA_CI_EXTRA_REPOSITORY_KEY}" -t "${CHROOT_PATH}/etc-target"
sed  '/127.0.0.1/s/localhost/pipeline.salsa.debian.org localhost/' /etc/hosts > ${CHROOT_PATH}/etc/hosts
PIUPARTS_DISTRIBUTION_ARG="--distribution $RELEASE"
if [ "$VENDOR" = "debian" ]; then \
  CODENAME=$(wget -O - ${SALSA_CI_MIRROR}/dists/${RELEASE}/Release | awk "/^Codename:/ { print \$2 }" | sed -e "s/-backports//"); \
  PIUPARTS_DISTRIBUTION_ARG="--distribution ${CODENAME}"; \
fi
(for PACKAGE in $(ls ${WORKING_DIR}/*.deb); do
  piuparts --mirror "${SALSA_CI_MIRROR} ${SALSA_CI_COMPONENTS}" ${SALSA_CI_PIUPARTS_ARGS} --scriptsdir /etc/piuparts/scripts --allow-database --warn-on-leftovers-after-purge --hard-link -e ${CHROOT_PATH} ${PIUPARTS_DISTRIBUTION_ARG} ${PACKAGE}
done) | filter-output
