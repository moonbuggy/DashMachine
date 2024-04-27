# syntax=docker/dockerfile:1.7-labs
# experimental syntax is required for 'COPY --exclude'

ARG BUILD_PYTHON_VERSION="3.8"
ARG FROM_IMAGE="moonbuggy2000/debian-slim-s6-python:${BUILD_PYTHON_VERSION}"

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

# enable virtual environment
ARG VIRTUAL_ENV
RUN python -m pip install virtualenv \
  && python -m virtualenv "${VIRTUAL_ENV}"

ARG APP_PATH
WORKDIR "${APP_PATH}"

COPY --exclude=docker-root . ./

# activate virtualenv
ENV VIRTUAL_ENV="${VIRTUAL_ENV}" \
  PATH="${VIRTUAL_ENV}/bin:$PATH"

RUN pip install --no-cache-dir -r requirements.txt \
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

ARG APT_CACHE
RUN export DEBIAN_FRONTEND="noninteractive" \
  && if [ ! -z "${APT_CACHE}" ]; then \
    echo "Acquire::http { Proxy \"${APT_CACHE}\"; }" > /etc/apt/apt.conf.d/proxy; fi \
  && apt-get update \
  && apt-get install --no-install-recommends -qy \
    inetutils-ping \
  && apt-get clean \
  && (rm -f /etc/apt/apt.conf.d/proxy 2>/dev/null || true)

ARG APP_PATH
COPY --from=builder "${APP_PATH}" "${APP_PATH}"
COPY --from=builder /docker-root/ /

EXPOSE 5000
VOLUME "${APP_PATH}/dashmachine/user_data"
