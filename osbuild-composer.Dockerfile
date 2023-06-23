FROM quay.io/fedora/fedora:37

RUN dnf -y install dnf-plugins-core
RUN dnf -y copr enable @osbuild/osbuild

RUN dnf -y install osbuild-composer composer-cli jq
COPY osbuild-composer-*.* /etc/systemd/system/
RUN systemctl enable \
  osbuild-composer.socket \
  osbuild-composer-proxy.socket \
  osbuild-composer-journal.service \
  osbuild-composer-loopback.service

CMD ["/sbin/init"]

RUN rm -rf /var/cache/dnf/*
