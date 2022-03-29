FROM ubuntu:latest

# RUN apk add --no-cache git
# RUN apk add --no-cache sed
RUN apt update
RUN apt install -y git
RUN apt install -y sed

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
