FROM alpine:3.15

RUN apk add --no-cache aws-cli docker-compose bash openssh curl \
    && wget -P / https://raw.githubusercontent.com/programic/bash-common/main/common.sh \
    && curl -sL https://sentry.io/get-cli/ | bash

COPY pipe /

RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]