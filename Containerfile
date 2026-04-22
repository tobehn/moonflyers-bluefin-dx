# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx

# Build-Arg aus GH Actions + ins RUN-Env heben
ARG LOGID_USERNAME
ENV USERNAME=${LOGID_USERNAME}

#Copy build file
COPY build_files /

# Base Image
#FROM ghcr.io/ublue-os/bazzite:stable

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# FROM ghcr.io/ublue-os/bluefin-dx:stable
FROM ghcr.io/ublue-os/bluefin-dx-nvidia-open:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

COPY tuxedo.repo /etc/yum.repos.d/tuxedo.repo
COPY fixtuxedo /usr/bin/fixtuxedo
COPY fixtuxedo.service /etc/systemd/system/fixtuxedo.service

# Public MOK (X.509 DER) für Modul-Signing-Verifikation und User-Enrollment.
# Public only — der private Key kommt zur Build-Zeit per --mount=type=secret rein.
COPY MOK.der /etc/pki/moonflyers-MOK.der

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    --mount=type=secret,id=mok-key \
    /ctx/build.sh && ostree container commit
    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
