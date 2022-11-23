FROM ubuntu:jammy

ENV DEBIAN_FRONTEND=noninteractive
ENV NONINTERACTIVE=1

RUN apt-get update && \
    apt-get install -y qemu-kvm \
    bridge-utils \
    virtinst\
    ovmf \
    qemu-utils \
    cloud-image-utils \
    ubuntu-drivers-common \
    whois \
    git \
    git-extras \
    tmux \
    iproute2 \
    vim \
    cloud-init \
    gettext-base && \
    apt-get autoremove -y

RUN git-force-clone \
    https://github.com/cloudymax/Scrap-Metal \
    /Scrap-Metal

WORKDIR /Scrap-Metal/virtual-machines

RUN git-force-clone \
    https://github.com/cloudymax/cloud-init-generator \
    cloud-init-generator && \
    git-force-clone \
    https://github.com/cloudymax/cigen-community-templates \
    cigen-community-templates
