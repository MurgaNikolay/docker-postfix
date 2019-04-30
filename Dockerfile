FROM ubuntu:trusty
MAINTAINER Elliott Ye

# Set noninteractive mode for apt-get
ENV DEBIAN_FRONTEND noninteractive

# Start editing
# Install package here for cache
RUN apt-get update && apt-get -y install supervisor postfix sasl2-bin opendkim opendkim-tools

COPY config/supervisord/* /etc/supervisor/available/
COPY config/supervisord/supervisord.conf /etc/supervisor/supervisord.conf
#Postfix
COPY config/postfix/sasl-smtpd.conf /etc/postfix/sasl/smtpd.conf
# Opendkim
COPY config/opendkim/opendkim-genkey.sh /usr/local/bin
COPY config/opendkim/default /etc/default/opendkim
COPY config/opendkim/opendkim.conf /etc/opendkim.conf
COPY config/opendkim/TrustedHosts /etc/opendkim/TrustedHosts
VOLUME /var/log
RUN mkdir -p /etc/postfix/certs /etc/opendkim/domainkeys && \
    touch /etc/opendkim/KeyTable /etc/opendkim/SigningTable && \
    ln -sf /etc/supervisor/available/rsyslog.conf /etc/supervisor/conf.d/rsyslog.conf && \
    ln -sf /etc/supervisor/available/postfix.conf /etc/supervisor/conf.d/postfix.conf
ADD config/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
