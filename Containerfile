ARG FROM=quay.io/centos/centos:stream9
FROM $FROM

ARG COPR=false

RUN if $COPR; then dnf -y install dnf-plugins-core && dnf -y copr enable @osbuild/osbuild && dnf -y copr enable @osbuild/osbuild-composer; fi && \
  dnf -y install osbuild-composer composer-cli jq && rm -rf /var/cache/dnf/*

COPY units/* /etc/systemd/system/

RUN systemctl enable \
  osbuild-composer.socket \
  osbuild-composer-proxy.socket \
  osbuild-composer-journal.service \
  osbuild-composer-loopback.service

CMD ["/sbin/init"]
