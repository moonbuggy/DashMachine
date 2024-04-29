# syntax=docker/dockerfile:1.7-labs
# experimental syntax is required for 'COPY --exclude'

ARG BUILD_PYTHON_VERSION="3.8"
ARG FROM_IMAGE="moonbuggy2000/alpine-s6-python:${BUILD_PYTHON_VERSION}"

# ARG BUILDER_ROOT="/docker-root"
ARG APP_PATH="/dashmachine"
ARG VIRTUAL_ENV="${APP_PATH}/venv"


## build a virtual environment
#
FROM "${FROM_IMAGE}" as builder

# use PyPi cache, if provided
ARG PYPI_INDEX="https://pypi.org/simple"
RUN (mv /etc/pip.conf /etc/pip.conf.bak 2>/dev/null || true) \
  && printf '%s\n' '[global]' "  index-url = ${PYPI_INDEX}" \
    "  trusted-host = $(echo "${PYPI_INDEX}" | cut -d'/' -f3 | cut -d':' -f1)" \
    >/etc/pip.conf

# install virtual environment
ARG VIRTUAL_ENV
RUN python -m pip install virtualenv \
  && python -m virtualenv "${VIRTUAL_ENV}"

ARG APP_PATH
WORKDIR "${APP_PATH}"

COPY --exclude=docker-root . ./

# activate virtualenv
ENV VIRTUAL_ENV="${VIRTUAL_ENV}" \
  PATH="${VIRTUAL_ENV}/bin:$PATH"

# Python wheels from pre_build
ARG TARGET_ARCH_TAG="amd64"
ARG IMPORTS_DIR=".imports"
COPY _dummyfile "${IMPORTS_DIR}/${TARGET_ARCH_TAG}*" "/${IMPORTS_DIR}/"

RUN python3 -m pip install --no-cache-dir --find-links "/${IMPORTS_DIR}/" -r requirements.txt \
  && (mv -f /etc/pip.conf.bak /etc/pip.conf 2>/dev/null || true)

COPY docker-root /docker-root

RUN add-contenv \
    APP_PATH="${APP_PATH}" \
    PATH="${PATH}" \
    VIRTUAL_ENV="${VIRTUAL_ENV}" \
    PRODUCTION=true \
  && cp /etc/contenv_extra /docker-root/etc/

## build the final image
#
FROM "${FROM_IMAGE}"

ARG APK_PROXY
RUN if [ ! -z "${APK_PROXY}" ]; then \
    alpine_minor_ver="$(grep -o 'VERSION_ID.*' /etc/os-release | grep -oE '([0-9]+\.[0-9]+)')"; \
    mv /etc/apk/repositories /etc/apk/repositories.bak; \
		echo "${APK_PROXY}/alpine/v${alpine_minor_ver}/main" >/etc/apk/repositories; \
		echo "${APK_PROXY}/alpine/v${alpine_minor_ver}/community" >>/etc/apk/repositories; \
	fi \
  && apk add --no-cache iputils-ping \
  && mv -f /etc/apk/repositories.bak /etc/apk/repositories

ARG APP_PATH
COPY --from=builder "${APP_PATH}" "${APP_PATH}"
COPY --from=builder /docker-root/ /

EXPOSE 5000
VOLUME "${APP_PATH}/dashmachine/user_data"
