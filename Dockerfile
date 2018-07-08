FROM ubuntu

MAINTAINER k-ishigaki <k-ishigaki@frontier.hokudai.ac.jp>

FROM alpine

# Default vars
ENV proxy_host 153.126.160.113
ENV proxy_port 8888
ENV proxy_user kazuki
ENV proxy_pass "\"4sPLA0027"
ENV proxy_pass_encoded "%224sPLA0027"
ENV http_proxy http://${proxy_user}:${proxy_pass}@${proxy_host}:${proxy_port}
ENV https_proxy ${http_proxy}
ENV HTTP_PROXY ${http_proxy}
ENV HTTPS_PROXY ${http_proxy}

# Install package
RUN env && apk update && apk --no-cache add squid gettext

EXPOSE 8080

RUN touch /var/log/squid/access.log \
    && chown squid:squid /var/log/squid/access.log

# Create template conf
RUN { \
      echo 'http_port 8080'; \
      echo 'acl all_ports port 0-65535'; \
      echo 'acl CONNECT method CONNECT'; \
      echo 'http_access allow all_ports'; \
      echo 'http_access allow CONNECT all_ports'; \
      echo 'http_access allow all'; \
      echo 'never_direct allow CONNECT'; \
      echo 'cache_peer ${proxy_host} parent ${proxy_port} 0 no-query no-netdb-exchange login=${proxy_user}:${proxy_pass_encoded}'; \
    } > /etc/squid.conf.template

# Create endpoint script
RUN { \
      echo '#!/bin/sh -e'; \
      echo 'envsubst < /etc/squid.conf.template > /etc/squid.conf'; \
      echo '/usr/sbin/squid -f /etc/squid.conf'; \
      echo 'tail -F /var/log/squid/access.log'; \
    } > /start \
    && chmod +x /start

CMD [ "/start" ]
