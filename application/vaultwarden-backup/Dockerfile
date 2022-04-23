FROM alpine:3

RUN apk update
RUN apk add bash
RUN apk add \
        curl \
        openssl \
        postgresql-client \
        py3-cryptography \
        py3-pip \

RUN pip3 install wheel
RUN pip3 install oci_cli

COPY setup_crontab.sh /setup_crontab.sh
COPY vaultwarden_backup.sh /vaultwarden_backup.sh
COPY container_healthcheck.sh /container_healthcheck.sh

HEALTHCHECK CMD bash /container_healthcheck.sh

ENTRYPOINT ["bash", "-x", "setup_crontab.sh"]
