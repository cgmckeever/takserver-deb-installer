#!/bin/bash

echo ""
echo "******************************************************"
echo "************* Creating Client Certs ******************"
echo "******************************************************"
echo ""

HASUSERS=1

mkdir -p /opt/tak/certs/files/clients

INTERMEDIARY_CA=$(<intermediary.txt)
TRUSTSTORE="truststore-${INTERMEDIARY_CA}.p12"
TAK_COT_PORT='8089'

if [ -z "$TAK_ALIAS" ]; then
  XTAK_ALIAS=${HOSTNAME//\./-}
  read -p "What is the alais of this Tak Server [${XTAK_ALIAS}]? " TAK_ALIAS
  TAK_ALIAS=${TAK_ALIAS:-$XTAK_ALIAS}
fi

NIC=$(<nic.txt)
EXT_IP=$(ip addr show $NIC | grep -m 1 "inet " | awk '{print $2}' | cut -d "/" -f1)

# Make the Client Keys
#
read -p "How many clients do you want to configure? " CLIENT_COUNT

CLIENT_ARR=()
for ((i=1; i<=$CLIENT_COUNT;i++)); do
  CLIENT_ARR+=($CLIENT_NAME)
  echo ""
  echo "************************************"
  read -p  "What is the username for client #$i? " USERNAME
  echo "************************************"
  echo ""

  echo "Creating certs for $USERNAME"
  cd /opt/tak/certs/
  sudo ./makeCert.sh client tc-$USERNAME

  # Make a folder per user
  #
  rm -rf /opt/tak/certs/files/clients/
  mkdir -p /opt/tak/certs/files/clients/$USERNAME

  #Copy over client certs
  #
  cp /opt/tak/certs/files/tc-$USERNAME.p12 /opt/tak/certs/files/clients/$USERNAME/$USERNAME.p12
  cp /opt/tak/certs/files/tc-$USERNAME.pem /opt/tak/certs/files/clients/$USERNAME/$USERNAME.pem
  cp /opt/tak/certs/files/$TRUSTSTORE /opt/tak/certs/files/clients/$USERNAME/$TRUSTSTORE
  cp /opt/tak/certs/files/itak-server-qr.png /opt/tak/certs/files/clients/$USERNAME/itak-server-qr.png

  tee /opt/tak/certs/files/clients/$USERNAME/manifest.xml >/dev/null << EOF
  <MissionPackageManifest version="2">
  <Configuration>
  <Parameter name="uid" value="bcfaa4a5-2224-4095-bbe3-fdaa22a82741"/>
  <Parameter name="name" value="${USERNAME}-${TAK_ALIAS}-DP"/>
  <Parameter name="onReceiveDelete" value="true"/>
  </Configuration>
  <Contents>
  <Content ignore="false" zipEntry="certs\server.pref"/>
  <Content ignore="false" zipEntry="certs\\${TRUSTSTORE}"/>
  <Content ignore="false" zipEntry="certs\\${USERNAME}.p12"/>
  </Contents>
  </MissionPackageManifest>
EOF


  tee /opt/tak/certs/files/clients/$USERNAME/server.pref >/dev/null << EOF
  <?xml version='1.0' encoding='ASCII' standalone='yes'?>
  <preferences>
    <preference version="1" name="cot_streams">
      <entry key="count" class="class java.lang.Integer">1</entry>
      <entry key="description0" class="class java.lang.String">${USERNAME}-${TAK_ALIAS}</entry>
      <entry key="enabled0" class="class java.lang.Boolean">true</entry>
      <entry key="connectString0" class="class java.lang.String">${EXT_IP}:$TAK_COT_PORT:ssl</entry>
    </preference>
    <preference version="1" name="com.atakmap.app_preferences">
      <entry key="displayServerConnectionWidget" class="class java.lang.Boolean">true</entry>
      <entry key="caLocation" class="class java.lang.String">cert/$TRUSTSTORE</entry>
      <entry key="caPassword" class="class java.lang.String">$CERTPASS</entry>
      <entry key="clientPassword" class="class java.lang.String">$CERTPASS</entry>
      <entry key="certificateLocation" class="class java.lang.String">cert/${USERNAME}.p12</entry>
    </preference>
  </preferences>
EOF

  cd /opt/tak/certs/files/clients/${USERNAME}/
  zip ${USERNAME}-${TAK_ALIAS}.zip ${USERNAME}.p12 ${USERNAME}.pem ${TRUSTSTORE} manifest.xml server.pref itak-server-qr.png
  rm ${USERNAME}.p12
  rm ${USERNAME}.pem
  rm $TRUSTSTORE
  rm manifest.xml
  rm server.pref
  rm itak-server-qr.png
  echo "user Data Package Created: /opt/tak/certs/files/clients/${USERNAME}/${USERNAME}-${TAK_ALIAS}.zip"
done

echo ""
echo "******************************************************"
echo "************* Finished Client Certs ******************"
echo "******************************************************"
echo ""