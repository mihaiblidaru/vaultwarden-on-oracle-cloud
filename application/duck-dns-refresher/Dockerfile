FROM alpine

RUN apk update
RUN apk upgrade
RUN apk add bash
RUN apk add curl

COPY refresh_duck_dns.sh refresh_duck_dns.sh
COPY container_healthcheck.sh container_healthcheck.sh

HEALTHCHECK CMD bash container_healthcheck.sh

ENTRYPOINT ["bash", "-x", "./refresh_duck_dns.sh"]
