# syntax=docker/dockerfile:1

# Keep both Bazzite FROM lines identical. This makes the build and final stages
# use precisely the same kernel.
FROM scratch AS build-context
COPY build_files /
COPY system_files /system_files

FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable AS it87-build
ARG IT87_COMMIT=490f76f61900c163fac5328506c49969bd716dc6
ARG IT87_VERSION=0.20260724
RUN --mount=type=bind,from=build-context,source=/,target=/ctx,ro \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build-it87.sh "${IT87_COMMIT}" "${IT87_VERSION}"

FROM ghcr.io/ublue-os/bazzite-nvidia-open:stable

COPY --from=it87-build /it87-root/ /

# Chrome installs its immutable payload below /opt. Bazzite normally points
# /opt at writable /var/opt, so replace only that image-local symlink.
RUN if [ -L /opt ]; then unlink /opt; fi && mkdir -p /opt

RUN --mount=type=bind,from=build-context,source=/,target=/ctx,ro \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
