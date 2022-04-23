FROM nginx:alpine

RUN apk add \
    bash \
    certbot \
    curl

# FROM certbot/certbot

# RUN apk add bash curl

COPY init.sh /
COPY tls_renew_certificate.sh /
COPY container_healthcheck.sh /
COPY challenge-hook.sh /
COPY cleanup-hook.sh /

RUN chmod +x /*.sh


# HEALTHCHECK CMD bash /container_healthcheck.sh

CMD ["bash", "init.sh"]
