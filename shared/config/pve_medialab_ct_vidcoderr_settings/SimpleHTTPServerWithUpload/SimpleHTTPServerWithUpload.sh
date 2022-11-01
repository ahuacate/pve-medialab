#!/bin/bash
clear
port=$(awk -F "=" '/HTTPSERVER_PORT/ {print $2}' /usr/local/bin/vidcoderr/vidcoderr.ini)
cd /mnt/public/autoadd/vidcoderr/
python3 /usr/local/bin/vidcoderr/SimpleHTTPServerWithUpload.py --bind $(hostname -I) ${port}