FROM alpine:3.20

RUN apk add --no-cache aws-cli docker-compose bash openssh curl doctl \
    && wget -P / https://raw.githubusercontent.com/programic/bash-common/main/common.sh \
    && curl -sL https://sentry.io/get-cli/ | bash \
    && printf '[safe]\n    directory = *\n' > /etc/gitconfig

COPY pipe /

RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]