#!/bin/bash
DOMAIN=$1
SELECTOR=${2:-"default"}
mkdir -p /etc/opendkim/domainkeys/${DOMAIN}
cd /etc/opendkim/domainkeys/${DOMAIN}
opendkim-genkey -r -d ${DOMAIN} -s ${SELECTOR}
