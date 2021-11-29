FROM alpine:3.15

RUN apk add --update --no-cache aws-cli docker-compose bash openssh \
    && wget -P / https://raw.githubusercontent.com/programic/bash-common/main/common.sh

COPY pipe /

RUN chmod a+x /*.sh

ENTRYPOINT ["/pipe.sh"]