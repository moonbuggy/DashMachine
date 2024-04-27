#! /bin/bash
# shellcheck disable=SC2034

DOCKER_REPO="${DOCKER_REPO:-moonbuggy2000/dashmachine}"

default_tag='latest'
all_tags='latest'

# start the builder proper
. "hooks/.build.sh"
