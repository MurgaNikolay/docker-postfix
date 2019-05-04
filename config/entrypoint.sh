#!/usr/bin/env bash
set -e
# POSTFIX
postconf -e myhostname=${MAIL_DOMAIN}
postconf -e mailbox_size_limit=0
postconf -e recipient_delimiter=+
postconf -F '*/*/chroot = n'
postconf -e smtpd_sasl_auth_enable=yes
postconf -e inet_protocols=${INET_PROTOCOLS:-"ipv4"}
postconf -e broken_sasl_auth_clients=yes
postconf -e smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination

echo ${SMTP_USER} | tr , \\n > /tmp/passwd
while IFS=':' read -r _user _pwd; do
  echo ${_pwd} | saslpasswd2 -p -c -u ${MAIL_DOMAIN} ${_user}
done < /tmp/passwd
chown postfix.sasl /etc/sasldb2

# TLS
if [[ -n "$(find /etc/postfix/certs -iname *.crt)" && -n "$(find /etc/postfix/certs -iname *.key)" ]]; then
  # /etc/postfix/main.cf
  postconf -e smtpd_tls_cert_file=$(find /etc/postfix/certs -iname *.crt)
  postconf -e smtpd_tls_key_file=$(find /etc/postfix/certs -iname *.key)
  chmod 400 /etc/postfix/certs/*.*
  # /etc/postfix/master.cf
  postconf -M submission/inet="submission   inet   n   -   n   -   -   smtpd"
  postconf -P "submission/inet/syslog_name=postfix/submission"
  postconf -P "submission/inet/smtpd_tls_security_level=encrypt"
  postconf -P "submission/inet/smtpd_sasl_auth_enable=yes"
  postconf -P "submission/inet/milter_macro_daemon_name=ORIGINATING"
  postconf -P "submission/inet/smtpd_recipient_restrictions=permit_sasl_authenticated,reject_unauth_destination"
fi

# OPENDKIM
rm -f /etc/supervisor/conf.d/opendkim.conf
if [[ -n "$(find /etc/opendkim/domainkeys -iname *.private)" ]]; then
  postconf -e milter_protocol=2
  postconf -e milter_default_action=accept
  postconf -e smtpd_milters=inet:localhost:12301
  postconf -e non_smtpd_milters=inet:localhost:12301

  ln -sf /etc/supervisor/available/opendkim.conf /etc/supervisor/conf.d/opendkim.conf
  echo "" > /etc/opendkim/KeyTable
  echo "" > /etc/opendkim/SigningTable

  shopt -s globstar
  for i in /etc/opendkim/domainkeys/**/*.private; do
     DOMAIN=$(basename $(dirname "$i"))
     FILENAME=$(basename "$i")
     SELECTOR="${FILENAME%.*}"

     if [ ${DOMAIN} == "domainkeys" ]; then
      DOMAIN=${MAIL_DOMAIN}
     fi
     echo "$SELECTOR._domainkey.$DOMAIN $DOMAIN:$SELECTOR:$i" >> /etc/opendkim/KeyTable
     echo "*@$DOMAIN $SELECTOR._domainkey.$DOMAIN" >> /etc/opendkim/SigningTable
  done
  set +e
  chown opendkim:opendkim $(find /etc/opendkim/domainkeys -iname *.private)
  chmod 400 $(find /etc/opendkim/domainkeys -iname *.private)
  set -e
fi
exec "$@"
