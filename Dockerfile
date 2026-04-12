FROM alpine:3.20

RUN apk add --no-cache bash util-linux

COPY src/ufw-manager /usr/local/bin/ufw-manager
RUN chmod +x /usr/local/bin/ufw-manager

ENTRYPOINT ["/usr/local/bin/ufw-manager"]