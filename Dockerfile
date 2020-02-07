FROM alpine

LABEL maintainer="Kazuki Ishigaki<k-ishigaki@frontier.hokudai.ac.jp>"

# Default vars
ARG proxy_host
ARG proxy_port
ARG proxy_auth_base64_encoded
ARG proxy_user
ARG proxy_pass_encoded

# http_proxy do not use proxy_user and proxy_pass
# because alpine apk uses proxy setting from HTTP_PROXY_AUTH
ENV http_proxy http://${proxy_host}:${proxy_port}
ENV https_proxy ${http_proxy}
ENV HTTP_PROXY ${http_proxy}
ENV HTTPS_PROXY ${http_proxy}

# Install package
RUN export proxy_auth=$(echo -n ${proxy_auth_base64_encoded} | base64 -d) \
    && export HTTP_PROXY_AUTH=basic:*:${proxy_auth} \
    && apk update && apk --no-cache add squid gettext curl

EXPOSE 8080

RUN touch /var/log/squid/access.log \
    && chown squid:squid /var/log/squid/access.log

# Create template conf
RUN { \
      echo 'http_port 8080'; \
      echo 'dns_defnames on'; \
      echo 'acl all_ports port 0-65535'; \
      echo 'acl CONNECT method CONNECT'; \
      echo 'http_access allow all_ports'; \
      echo 'http_access allow CONNECT all_ports'; \
      echo 'http_access allow all'; \
	  echo 'never_direct allow all'; \
      echo 'never_direct allow CONNECT'; \
      echo 'cache_peer ${proxy_host} parent ${proxy_port} 0 proxy_only no-digest no-netdb-exchange login=${proxy_user}:${proxy_pass_encoded}'; \
	  echo 'forwarded_for off'; \
	  echo 'request_header_access Referer deny all'; \
      echo 'request_header_access X-Forwarded-For deny all'; \
      echo 'request_header_access Via deny all'; \
      echo 'request_header_access Cache-Control deny all'; \
	  echo 'reply_header_access Referer deny all'; \
      echo 'reply_header_access X-Forwarded-For deny all'; \
      echo 'reply_header_access Via deny all'; \
      echo 'reply_header_access Cache-Control deny all'; \
    } > /etc/squid.conf.template

# Create endpoint script
RUN { \
      echo '#!/bin/sh -e'; \
      echo 'export proxy_auth=$(echo -n ${proxy_auth_base64_encoded} | base64 -d)'; \
      echo 'envsubst < /etc/squid.conf.template > /etc/squid.conf'; \
      echo '/usr/sbin/squid -f /etc/squid.conf'; \
      echo 'tail -f /dev/null'; \
    } > /start \
    && chmod +x /start

CMD [ "/start" ]
