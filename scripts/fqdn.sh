#!/bin/bash

echo ""
echo "******************************************************"
echo "***************** Setup Signed FQDN ******************"
echo "******************************************************"
echo ""


# install certbot
#
sudo apt install -y certbot openjdk-16-jre-headless

read -p  "What is your domain name? ex: atakhq.com or tak-public.atakhq.com " FQDN

# request inital cert
#
echo ""
echo "Requesting a new certificate..."
echo ""
read -p "What is your email? [Needed for Letsencrypt Alerts] : " EMAIL

if certbot certonly --standalone -d $FQDN -m $EMAIL --agree-tos --non-interactive; then
  echo "Certificate obtained successfully!"
else
  echo "Error obtaining certificate: $(sudo certbot certificates)"
  exit 1
fi

sudo openssl pkcs12 -export -in /etc/letsencrypt/live/$FQDN/fullchain.pem \
  -inkey /etc/letsencrypt/live/$FQDN/privkey.pem \
  -name $TAK_ALIAS \
  -out ~/$TAK_ALIAS.p12 \
  -passout pass:$CERTPASS

echo "***"
echo ""
echo " If asked to save file because an existing copy exists, reply Y."
read -p "Press any key to resume setup... "
echo ""

sudo keytool -importkeystore \
  -deststorepass $CERTPASS \
  -srcstorepass $CERTPASS \
  -destkeystore ~/$TAK_ALIAS.jks \
  -srckeystore ~/$TAK_ALIAS.p12 \
  -srcstoretype PKCS12

sudo keytool -import \
  -alias bundle \
  -trustcacerts \
  -deststorepass $CERTPASS \
  -srcstorepass $CERTPASS \
  -file /etc/letsencrypt/live/$FQDN/fullchain.pem \
  -keystore ~/$TAK_ALIAS.jks

# copy files to common folder
#
sudo mkdir -p /opt/tak/certs/letsencrypt
sudo mv ~/$TAK_ALIAS.jks /opt/tak/certs/letsencrypt
sudo mv ~/$TAK_ALIAS.p12 /opt/tak/certs/letsencrypt
sudo chown $TAKUSER:$TAKUSER -R /opt/tak/certs/letsencrypt

sudo update-alternatives --set java /usr/lib/jvm/java-11-openjdk-amd64/bin/java

HAS_FQDNSSL=1

echo ""
echo "******************************************************"
echo "*************** Completed Signed FQDN ****************"
echo "******************************************************"
echo ""

