#!/bin/bash

echo ""
echo "******************************************************"
echo "*********** Installing simple-rtsp-server ************"
echo "******************************************************"
echo ""


rm -f rtsp-simple-server_v0.17.13_linux_amd64.tar.gz
wget https://github.com/aler9/rtsp-simple-server/releases/download/v0.17.13/rtsp-simple-server_v0.17.13_linux_amd64.tar.gz

tar -zxvf rtsp-simple-server_v0.17.13_linux_amd64.tar.gz
rm -f rtsp-simple-server_v0.17.13_linux_amd64.tar.gz
sudo mv rtsp-simple-server /usr/local/bin/rtsp-simple-server

sudo cp files/rtsp-simple-server.default.yml /usr/local/etc/rtsp-simple-server.yml
sudo cp files/rtsp-simple-server.default.service /etc/systemd/system/rtsp-simple-server.service

# [TODO] Open RTSP/RTMP Ports in firewall
#
#sudo ufw allow 554/tcp
#sudo ufw allow 554/udp
#sudo ufw allow 1935/tcp
#sudo ufw allow 1935/udp
#sudo ufw reload

# Enable the service on server boot
#
sudo systemctl daemon-reload
sudo systemctl enable rtsp-simple-server
sudo systemctl start rtsp-simple-server

# Connection Info
#
PUB_SERVER_IP=$(ip addr show $NIC | awk 'NR==3{print substr($2,1,(length($2)-3))}')

HAS_SIMPLERTSP=1

echo ""
echo "******************************************************"
echo "************ Finished simple-rtsp-server *************"
echo "******************************************************"
echo ""