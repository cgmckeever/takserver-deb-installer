#!/bin/bash



echo ""
echo "******************************************************"
echo "***** Import TAK Server DEB using Google Drive *******"
echo "******************************************************"
echo ""


FILE_NAME=takserver.release.deb

SUCCESS=false
while [[ $SUCCESS == false ]]; do
  echo ""
  echo ""
  echo "Find your Google Drive FILE-ID"
  echo ""
  echo "Right click > Get Link > Allow Sharing to anyone with link > Open share link"
  echo "'https://drive.google.com/file/d/<YOUR_FILE-ID_IS_HERE>/view?usp=sharing'"
  echo ""
  read -p "What is the FILE-ID : " FILE_ID

  sudo wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=$FILE_ID' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p'
  sudo wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=t&id=$FILE_ID" -O $FILE_NAME
  sudo rm -rf /tmp/cookies.txt

  if [[ -f $FILE_NAME && -s $FILE_NAME ]]; then
    echo "File found!"
    SUCCESS=true

    echo ""
    echo "******************************************************"
    echo "*********** Google Drive Import Complete *************"
    echo "******************************************************"
    echo ""

  else
    read -p "Download failed. Would you like to retry? (y/n)" RETRY

    if [[ $RETRY == "n" ]]; then
      echo "Quitting Install Script..."
      sleep 2
      exit
    fi
  fi
done

