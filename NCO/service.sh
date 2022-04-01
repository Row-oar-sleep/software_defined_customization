#!/bin/bash

#Purpose:  establishes DCA service on a Layer 4.5 host or middlebox





# ************** STANDARD PARAMS MUST GO HERE ****************
NCO_DIR=$GIT_DIR/NCO




# ************** STANDARD PARAMS MUST GO HERE ****************

# Force root
if [[ "$(id -u)" != "0" ]];
then
	echo "This script must be run as root" 1>&2
	exit -1
fi



echo "Installing NCO service"


LOADER_FILE=/etc/systemd/system/nco.service

if test -f "$LOADER_FILE"; then
    echo "$LOADER_FILE exists."
		rm $LOADER_FILE
fi

touch $LOADER_FILE

cat <<EOT >> $LOADER_FILE
[Unit]
Description=NCO systemd service.

[Service]
Type=simple
ExecStart='$NCO_DIR/NCO.py'

[Install]
WantedBy=multi-user.target
EOT

#register loader with systemd
systemctl enable nco.service

# start DCA service
systemctl start nco.service
