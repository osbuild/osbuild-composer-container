FROM quay.io/fedora/fedora:37

RUN dnf -y install osbuild-composer composer-cli socat jq
COPY osbuild-composer-*.* /etc/systemd/system/
RUN systemctl enable \
  osbuild-composer.socket \
  osbuild-composer-proxy.socket \
  osbuild-composer-journal.service \
  osbuild-composer-loopback.service
EXPOSE 8080

CMD ["/sbin/init"]

RUN rm -rf /var/cache/dnf/*
