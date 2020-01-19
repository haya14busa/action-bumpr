FROM alpine:3.10

RUN apk --no-cache add git jq curl grep coreutils

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
