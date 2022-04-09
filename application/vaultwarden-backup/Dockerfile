FROM alpine:3

RUN apk update
RUN apk add bash
RUN apk add \
        postgresql-client \
        py3-pip \
        py3-cryptography

RUN pip3 install wheel
RUN pip3 install oci_cli

COPY setup_crontab.sh /setup_crontab.sh
COPY backup.sh /backup.sh
COPY container_healthcheck.sh /container_healthcheck.sh

HEALTHCHECK CMD bash /container_healthcheck.sh

ENTRYPOINT ["bash", "-x", "setup_crontab.sh"]
