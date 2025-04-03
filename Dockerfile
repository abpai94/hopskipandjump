FROM debian:bookworm-slim

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt update && \
    apt upgrade -y --no-install-recommends && \
    apt install -y --no-install-recommends pipx && \
    apt install -y --no-install-recommends curl && \
    apt install -y --no-install-recommends jq && \
    apt install -y --no-install-recommends gettext

RUN pipx install linode-cli

ENV PATH="$PATH:/root/.local/bin/"

RUN mkdir /app
WORKDIR /app

RUN mkdir /app/bin
COPY ./bin/deployment.sh /app/bin/vpn
COPY ./bin/configuration_full_deployment.sh /app/bin/
COPY ./bin/configuration_self_hosted.sh /app/bin/
RUN chmod +x /app/bin/*

ENV PATH="$PATH:/app/bin"

RUN mkdir /app/data

RUN mkdir /app/conf.example
COPY ./conf.example/* /app/conf.example/

ENTRYPOINT ["tail","-f","/dev/null"]
