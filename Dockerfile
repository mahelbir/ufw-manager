FROM alpine:3.20

RUN apk add --no-cache bash util-linux

COPY src/ufw-manager /usr/local/bin/ufw
RUN chmod +x /usr/local/bin/ufw

COPY src/templates/default /usr/local/share/ufw-manager/templates/default

RUN printf '%s\n' \
'if [ -t 1 ] && [ -z "${UFW_BANNER_SHOWN:-}" ]; then' \
'  export UFW_BANNER_SHOWN=1' \
'  /usr/local/bin/ufw help' \
'  printf "\n\033[1;32m>>> Run \`ufw <command>\` to execute <<<\033[0m\n\n"' \
'fi' \
    > /root/.bashrc \
 && cp /root/.bashrc /root/.profile \
 && cp /root/.bashrc /root/.shrc
ENV ENV=/root/.shrc

ENTRYPOINT ["/usr/local/bin/ufw"]