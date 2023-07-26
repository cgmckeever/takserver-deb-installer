#!/bin/bash

echo ""
echo ""
echo "This script will install the necessary dependancies for TAK Server and complete the install using the .deb package"
echo ""
echo ""
echo "!------"
echo "!------ This will take ~5-10 min so please be patient ------! "
echo "!------"
echo ""
echo ""
read -p "Press any key to begin... "
echo ""

CERTPASS=atakatak

# Get the Ubuntu version number
#
version=$(lsb_release -rs)

# Check the version
#
if [[ "$version" != "20.04" &&  "$version" != "22.04" ]]; then
    echo "Found Ubuntu $version"
    echo "Error: This script requires Ubuntu 20.04 or 22.04"
    exit
fi

WORKDIR=$(pwd)

echo "******************************************************"
echo "*************** Installl Dependencies ****************"
echo "******************************************************"
echo ""

sudo apt -y install curl gnupg gnupg2

# Import postgres repo
#

#curl -fSsL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | \
#    sudo tee /usr/share/keyrings/postgresql.gpg > /dev/null

sudo mkdir /etc/apt/keyrings/
sudo curl https://www.postgresql.org/media/keys/ACCC4CF8.asc --output /etc/apt/keyrings/postgresql.asc

sudo rm -f /etc/apt/sources.list.d/postgresql.list
sudo sh -c 'echo "deb [signed-by=/etc/apt/keyrings/postgresql.asc] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/postgresql.list'

sudo apt-get -y update

# Get dependencies
#
sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    dirmngr \
    git \
    nano \
    net-tools \
    openjdk-11-jdk \
    openssl \
    software-properties-common \
    qrencode \
    ufw \
    unzip \
    vim \
    wget \
    zip

if [ $? -ne 0 ]; then
    echo "Error installing dependencies...."
    read -n 1 -s -r -p "Press any key to exit...."
    exit 1
fi

echo ""
echo "******************************************************"
echo "*************** Finished Dependencies ****************"
echo "******************************************************"
echo ""


# Get important values
#
XTAK_ALIAS=${HOSTNAME//\./-}
read -p "What is the alais of this Tak Server [${XTAK_ALIAS}]? " TAK_ALIAS
TAK_ALIAS=${TAK_ALIAS:-$XTAK_ALIAS}

echo ""
echo "Available Network Interface"
echo ""
ip link show
echo ""
echo ""

XNIC=$(route | grep default | awk '{print $8}')
read -p "Enter NIC [$XNIC] : " NIC
NIC=${NIC:-$XNIC}
echo $NIC > nic.txt
echo "Using $NIC as network interface"

IP=$(ip addr show $NIC | grep -m 1 "inet " | awk '{print $2}' | cut -d "/" -f1)

echo ""
read -p "Pull image from Google Drive [Y/n] : " GOOGLE
GOOGLE=${GOOGLE:-Y}

if [[ $GOOGLE == "y" || $GOOGLE == "Y" ]]; then
    source ./slurp-google.sh
else
    read -p "What is your file name? " FILE_NAME
fi


echo ""
echo "******************************************************"
echo "*************** Generating Server Users **************"
echo "******************************************************"
echo ""

# Generate tak user
#
#
# User Info
chars='!@#%^*()_+abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
length=15
has_upper=false
has_lower=false
has_digit=false
has_special=false

TAKUSER="tak"
TAKUSER_NAME="Tak User"

while [[ "$has_upper" == false || "$has_lower" == false || "$has_digit" == false || "$has_special" == false ]]; do
    TAKUSER_PASS=$(head /dev/urandom | tr -dc "$chars" | head -c "$length")
    for (( i=0; i<${#TAKUSER_PASS}; i++ )); do
        char="${TAKUSER_PASS:i:1}"
        if [[ "$char" =~ [A-Z] ]]; then
            has_upper=true
        elif [[ "$char" =~ [a-z] ]]; then
            has_lower=true
        elif [[ "$char" =~ [0-9] ]]; then
            has_digit=true
        elif [[ "$char" =~ [!@#%^*()_+] ]]; then
            has_special=true
        fi
    done
done

# Create the new user; add to sudo
#
sudo useradd -m -s /bin/bash -c TAKUSER_NAME $TAKUSER
echo "$TAKUSER:$TAKUSER_PASS" | chpasswd
usermod -aG sudo $TAKUSER

echo "Generated tak user: $TAKUSER password: $TAKUSER_PASS"


# TAK-ADMIN
#
length=15
has_upper=false
has_lower=false
has_digit=false
has_special=false

TAKADMIN=tak-admin

while [[ "$has_upper" == false || "$has_lower" == false || "$has_digit" == false || "$has_special" == false ]]; do
    TAKADMIN_PASS=$(head /dev/urandom | tr -dc "$chars" | head -c "$length")
    for (( i=0; i<${#TAKADMIN_PASS}; i++ )); do
        char="${TAKADMIN_PASS:i:1}"
        if [[ "$char" =~ [A-Z] ]]; then
            has_upper=true
        elif [[ "$char" =~ [a-z] ]]; then
            has_lower=true
        elif [[ "$char" =~ [0-9] ]]; then
            has_digit=true
        elif [[ "$char" =~ [!@#%^*()_+] ]]; then
            has_special=true
        fi
    done
done

echo "Generated admin web-portal password: ${TAKADMIN_PASS}"

echo ""
echo "******************************************************"
echo "*************** Server Users Generated ***************"
echo "******************************************************"
echo ""

read -p "Do you want to install and configure simple-rtsp-server? y or n " response
if [[ $response =~ ^[Yy]$ ]]; then
    source ./simple-rtsp-server.sh
else
    echo "skipping simple-rtsp-server setup..."
    echo ""
fi

#Install Tak Sever
#
echo ""
echo "******************************************************"
echo "*************** Installing Takserver *****************"
echo "******************************************************"
echo ""

RETRY_LIMIT=5

for ((i=1;i<=RETRY_LIMIT;i++)); do
    sudo apt install -y ./$FILE_NAME && break
    echo "Retry $i: Failed to install the package. Retrying in 5 seconds..."
    sleep 5
done

sudo chown -R $TAKUSER:$TAKUSER /opt/tak

if [ -f /opt/tak/db-utils/takserver-setup-db.sh ]; then
    ## Strange 4.8 error
    sudo ln -s /bin/systemctl /usr/bin/systemctl
    systemctl stop takserver
    sudo /opt/tak/db-utils/takserver-setup-db.sh
fi

sudo systemctl daemon-reload
sudo systemctl start takserver

echo ""
echo "******************************************************"
echo "************* Done Installing Takserver **************"
echo "******************************************************"
echo ""

# wait for 30seconds so takserver can launch
#
echo ""
echo ".... Waiting 30 seconds for Tak Server to Load ...."
sleep 30


# FQDN Setup
read -p "Do you want to setup a FQDN? y or n " response
if [[ $response =~ ^[Yy]$ ]]; then
    source ./fqdn.sh
else
  HAS_FQDNSSL=0
  echo "skipping FQDN setup..."
  echo ""
fi

echo ""
echo "******************************************************"
echo "*************** Creating Server Certs ****************"
echo "******************************************************"
echo ""

# Need to build CoreConfig.xml and put it into /opt/tak/CoreConfig.xml so next script uses it to make certs
echo "SSL Configuration: Hit enter (x3) to accept the defaults:"

read -p "State (for cert generation). Default [state] :" state
read -p "City (for cert generation). Default [city]:" city
read -p "Organizational Unit (for cert generation). Default [org_unit]:" orgunit

# define the input file path
#
CERTMETAPATH="/opt/tak/certs/cert-metadata.sh"

if [ -z "$state" ]; then
	# Default state to "STATE"
	sed -i 's/\${STATE}/\${STATE:-STATE}/g' "$CERTMETAPATH"
else
	# Set new defualt from user entry
	sed -i 's/\${STATE}/\${STATE:-$state}/g' "$CERTMETAPATH"
fi

if [ -z "$city" ]; then
	# Default city to "CITY"
	sed -i 's/\${CITY}/\${CITY:-CITY}/g' "$CERTMETAPATH"
else
	# Set new defualt from user entry
	sed -i 's/\${CITY}/\${CITY:-$city}/g' "$CERTMETAPATH"
fi

if [ -z "$orgunit" ]; then
	# Default org unit to "ORG_UNIT"
	sed -i 's/\${ORGANIZATIONAL_UNIT}/\${ORGANIZATIONAL_UNIT:-ORG_UNIT}/g' "$CERTMETAPATH"
else
	# Default org unit to "ORG_UNIT"
	sed -i 's/\${ORGANIZATIONAL_UNIT}/\${ORGANIZATIONAL_UNIT:-$orgunit}/g' "$CERTMETAPATH"
fi

# Update local env if the above file edits dont work
# bunch of people reporting issues here
#
export STATE=$state
export CITY=$city
export ORGANIZATIONAL_UNIT=$orgunit

INTERMEDIARY_CA=${TAK_ALIAS}-Intermediate-CA
echo ${INTERMEDIARY_CA} > intermediary.txt

# NOTE: some people are getting errors here, adding more error trapping
#
if [ -d "/opt/tak/certs" ] && [ -x "/opt/tak/certs/makeRootCa.sh" ]; then
    echo ""
else
    if [ ! -d "/opt/tak/certs" ]; then
        echo "/opt/tak/certs Path does not exist, cannot finish install"
    else
        echo "Cert Setup Script exists but is not executable, are you running this as root?"
    fi
    read -n 1 -s -r -p "Press any key to exit...."
    exit 1
fi

while :
do
	echo " YOU ARE LIKELY GOING TO SEE ERRORS FOR java.lang.reflect (due to Tak Server Initializing)"
    echo " ignore it and let the script finish it will keep retrying until successful"
	read -p "Press any key to begin..."
    echo ""

	cd /opt/tak/certs
    sudo ./makeRootCa.sh --ca-name ${TAK_ALIAS}-CA

	if [ $? -eq 0 ]; then
        echo ""
		echo " Setting up Certificate Enrollment so you can assign user/pass for login."
		echo " When asked to move files around, reply Yes"
		read -p "Press any key to continue..."

		# Make the int cert and edit the tak config to use it
        #
		echo "Generating Intermediate Cert"
		while :
		do
			sudo ./makeCert.sh ca ${INTERMEDIARY_CA}

			if [ $? -eq 0 ]; then
				break
			else 
				echo "Retry in 10 sec..."
				sleep 10
			fi
		done

	
		sudo ./makeCert.sh server takserver

		if [ $? -eq 0 ]; then
			sudo ./makeCert.sh client ${TAKADMIN}

			if [ $? -eq 0 ]; then
				break
			else 
				sleep 5
			fi
		else
			sleep 5
		fi
	fi
done

cd $WORKDIR

echo ""
echo "******************************************************"
echo "************** Completed Server Certs ****************"
echo "******************************************************"
echo ""

# Create local adminstrative access to the configuration interface:
#

echo ""
echo "******************************************************"
echo "***************** Create Admin User ******************"
echo "******************************************************"
echo ""

while :
do
	sudo java -jar /opt/tak/utils/UserManager.jar usermod -A -p "${TAKADMIN_PASS}" ${TAKADMIN}

	if [ $? -eq 0 ]; then
		sudo java -jar /opt/tak/utils/UserManager.jar certmod -A /opt/tak/certs/files/tak-admin.pem
		if [ $? -eq 0 ]; then
			break
		else
			sleep 10
		fi
	fi
done

echo ""
echo "******************************************************"
echo "************* Completed Create Admin User ************"
echo "******************************************************"
echo ""

read -p "Do you want to create additional connection packages for users? y or n " CREATEUSERS
if [[ $CREATEUSERS =~ ^[Yy]$ ]]; then
    source ./user-cert-create.sh
    cd $WORKDIR
fi

echo ""
echo ""
echo "******************************************************"
echo "*************** UPDATING CORECONFIG.XML **************"
echo "******************************************************"
echo ""

max_retries=5
retry_sleep=10
retry_count=0
line_break="\n"
CONFIGFILE="/opt/tak/CoreConfig.xml"
cp $CONFIGFILE "/opt/tak/CoreConfig.$(date +%s).xml"

while [[ $retry_count -lt $max_retries ]]
do
    if [ "$HAS_FQDNSSL" = "1" ]; then
        while [[ $retry_count -lt $max_retries ]]
        do
            echo "Replacing 8446 TLS with LetsEncrypt"
            echo ""
            search='<connector port="8446" clientAuth="false" _name="cert_https"\/>'
            replace='<connector port="8446" clientAuth="false" _name="cert_https" truststorePass="atakatak" truststoreFile="TRUSTSTORE" truststore="JKS" keystorePass="atakatak" keystoreFile="LETSENCRYPT" keystore="JKS"\/>'
            sed -i "s/$search/$replace/g" $CONFIGFILE

          if [[ $? -eq 0 ]]; then
            # Success
            break
          else
            # Retry after intervala
            sleep $retry_sleep
            retry_count=$((retry_count+1))
          fi
        done

        if [[ $retry_count -eq $max_retries ]]; then
          echo "Failed to update CoreConfig.xml after $retry_count retries"
          exit 1
        fi
    fi

    echo "Removing unsecure ports"
    echo ""
    ports_to_remove=(
        '8080'
        '8087'
        '8088'
        '8089'
    )

    for port in "${ports_to_remove[@]}"; do
        echo "Port: ${port}"
        sudo sed -i "/$port/d" $CONFIGFILE
    done

    echo "Add TLS 8089 port"
    echo ""
    sudo sed -i '3 a\        <input _name="cassl" auth="x509" protocol="tls" port="8089" />' $CONFIGFILE

    echo "Replacing CA Config"
    echo ""
    search='<dissemination smartRetry="false"\/>'
    replace=${search}${line_break}'    <certificateSigning CA="TAKServer">'${line_break}'        <certificateConfig>'${line_break}'            <nameEntries>'${line_break}'                <nameEntry name="O" value="TAK"\/>'${line_break}'                <nameEntry name="OU" value="TAK"\/>'${line_break}'            <\/nameEntries>'${line_break}'        <\/certificateConfig>'${line_break}'        <TAKServerCAConfig keystore="JKS" keystoreFile="INTERMEDIARY" keystorePass="atakatak" validityDays="30" signatureAlg="SHA256WithRSA"\/>'${line_break}'    <\/certificateSigning>'
    sed -i "s/$search/$replace/g" $CONFIGFILE

    echo "Add TLS Config"
    echo ""
    search='<tls keystore="JKS" keystoreFile="certs\/files\/takserver.jks" keystorePass="atakatak" truststore="JKS" truststoreFile="certs\/files\/truststore-root.jks" truststorePass="atakatak" context="TLSv1.2" keymanager="SunX509"\/>'
    replace='<tls keystore="JKS" keystoreFile="certs\/files\/takserver.jks" keystorePass="atakatak" truststore="JKS" truststoreFile="TRUSTSTORE" truststorePass="atakatak" context="TLSv1.2" keymanager="SunX509"\/>\n      <crl _name="TAKServer CA" crlFile="CRL_FILE"\/>'
    sed -i "s/$search/$replace/" $CONFIGFILE

    search='<auth>'
    replace='<auth x509groups="true" x509addAnonymous="false" x509useGroupCache="true" x509checkRevocation="true">'
    sed -i "s/$search/$replace/g" $CONFIGFILE

    echo "Finalizing Config"
    echo ""
    sed -i "s/atakatak/${CERTPASS}/g" $CONFIGFILE

    LETSENCRYPT="certs\/letsencrypt\/${TAK_ALIAS}.jks"
    sed -i "s/LETSENCRYPT/${LETSENCRYPT}/g" $CONFIGFILE

    CRL_FILE="certs\/files\/${INTERMEDIARY_CA}.crl"
    sed -i "s/CRL_FILE/${CRL_FILE}/g" $CONFIGFILE

    INTERMEDIARY="certs\/files\/${INTERMEDIARY_CA}-signing.jks"
    sed -i "s/INTERMEDIARY/${INTERMEDIARY}/g" $CONFIGFILE

    TRUSTSTORE="certs\/files\/truststore-${INTERMEDIARY_CA}.jks"
    sed -i "s/TRUSTSTORE/${TRUSTSTORE}/g" $CONFIGFILE

  if [[ $? -eq 0 ]]; then
    # Success
    break
  else
    # Retry after interval
    sleep $retry_sleep
    retry_count=$((retry_count+1))
  fi
done

if [[ $retry_count -eq $max_retries ]]; then
  echo "Failed to update ${CONFIGFILE} after ${retry_count} retries"
  exit 1
fi

echo ""
echo "******************************************************"
echo "*************** UPDATED CORECONFIG.XML ***************"
echo "******************************************************"
echo ""

echo ""
echo "******************************************************"
echo "***** RESTARTING TAKSERVER FOR CHANGES TO APPLY ******"
echo "******************************************************"
echo ""

sudo systemctl restart takserver
sudo systemctl enable takserver

echo ""
echo ""
echo ""
echo "" > install.txt
echo "********************************************************************" >> install.txt
echo "*" >> install.txt
echo "*" >> install.txt
echo "                        SERVER INFORMATION" >> install.txt
echo "*" >> install.txt
echo "*" >> install.txt
echo "********************************************************************" >> install.txt
echo "" >> install.txt

URL=$IP
if [ "$HAS_FQDNSSL" = "1" ]; then
    URL=$FQDN
fi

echo "Server IP: ${IP}" >> install.txt
echo "Server API Address API [certificate auth] (SSL): https://${URL}:8089" >> install.txt
echo "Server ManagementAddress [certificate auth] (SSL): https://${URL}:8443" >> install.txt
echo "Server Management Address [username/pass auth] (SSL): https://${URL}:8446" >> install.txt
echo ""
echo "Create new users here: https://${URL}:8446/user-management/index.html#!/" >> install.txt

echo "" >> install.txt
echo "" >> install.txt
echo "Sytem User:" >> install.txt
echo "  user: ${TAKUSER}" >> install.txt
echo "  password: ${TAKUSER_PASS}" >> install.txt
echo "" >> install.txt
echo "" >> install.txt
echo "Web Admin:" >> install.txt
echo "  user: ${TAKADMIN}" >> install.txt
echo "  password: ${TAKADMIN_PASS}" >> install.txt
echo ""
cat install.txt
echo ""
echo "This information has been written to install.txt"


if [ "$HASUSERS" = "1" ]; then
    echo ""
    echo "$CLIENT_COUNT User Connection Packages Created"
    echo "Zip Files located in: /opt/tak/certs/files/clients"
    echo ""
fi

if [ "$HAS_FQDNSSL" = "1" ]; then
	echo "********************************************************************"
    echo "*"
	echo "                        CONNECTION HELP"
    echo "*"
	echo "********************************************************************"

	echo "You should now be able to authenticate ITAK and ATAK clients using only user/password and server URL."
	echo " "
	echo "====================="
	echo "        ATAK"
	echo "====================="
	echo ""
	echo "Settings > Network Preferences > Server Connections > New Connection"
	echo ""
	echo "Name: <whatever-you-want-connection-named-as>"
	echo "Address: $FQDN"
	echo "Use Authentication: NOT checked"
	echo "Enroll for Client Certificate: Checked"
	echo "Click OK Button"
	echo ""
	echo "Next you will be prompted for your username/password and the connection will"
    echo "establish and finish setup on your EUD"
	echo ""
    echo ""
	echo "====================="
    echo "        ITAK"
    echo "====================="
	echo ""
	echo "~~~ SCAN QR CODE BELOW INSIDE ITAK TO SETUP SERVER CONNECTION ~~~ "
	echo "(There is also a copy of this image saved at /opt/tak/certs/files/itak-server-qr.png)"
	echo ""

    # ITAK QR Code on screen
    #
	echo "$HOSTNAME,$FQDN,8089,SSL" | qrencode -t UTF8

	# Save ITAK QR png to /opt/tak/certs/files
    #
	echo "$HOSTNAME,$FQDN,8089,SSL" | qrencode -s 10 -o /opt/tak/certs/files/itak-server-qr.png
else
	echo "********************************************************************"
    echo "*"
	echo "                      CERTIFICATE INFORMATION"
    echo "*"
	echo "********************************************************************"
	echo ""
	echo "Run the following command on your LOCAL machine to download the common cert"
	echo ""
	echo "ATAK - You will need this file for user/pass auth if you do not have a FQDN with SSL setup"
	echo "ITAK - Requires FQDN SSL and has QR code auth"
	echo ""
	echo "scp tak@$IP:/opt/tak/certs/files/truststore-${INTERMEDIARY_CA}.p12 ~/Downloads"
    echo ""
    echo ""
fi

# ADD-ONS
#
if [ "$HAS_SIMPLERTSP" = "1" ]; then
    echo " "
    echo "********************************************************************"
    echo "*"
    echo "                Simple RTSP Server should be running"
    echo "*"
    echo "********************************************************************"
    echo ""
    echo "Verfiy by running the following command:"
    echo "sudo systemctl status rtsp-simple-server"
    echo ""
    echo "********************************************************************"
    echo ""
    echo "You are ready to start streaming video, be sure to unblock the following ports "
    echo "in your firewall config. (TCP & UDP)"
    echo ""
    echo "RTSP ADDRESS: $IP:554"
    echo "RTMP ADDRESS: $IP:1935"
    echo ""
    echo "********************************************************************"
    echo ""
    echo ""
fi

echo ""
echo "******************************************************"
echo "*"
echo "********** Tak Server Installation Complete **********"
echo "*"
echo "******************************************************"
echo ""
