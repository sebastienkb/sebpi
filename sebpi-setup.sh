#!/bin/bash

PUSHBULLET_API_KEY="$1"

SEBPI_UPDATE_SCRIPT=/boot/sebpi-update.sh
SEBPI_INSTALLED_FILE=/boot/sebpi.installed
SEBPI_LOCALE_GEN_FILE=/boot/sebpi.locale.gen

SEBPI_INSTALLED=0
SEBPI_LOCALE_GEN=0

if [ -e "$SEBPI_INSTALLED_FILE" ]; then
	echo "This is not the first time this script is run, ignoring some one-time settings."
	SEBPI_INSTALLED=1
fi

if [ -e "$SEBPI_LOCALE_GEN_FILE" ]; then
	SEBPI_LOCALE_GEN=1
fi

# Fix locale issues on Debian
sudo sed -i 's/^AcceptEnv.*/#AcceptEnv LANG LC_*/' /etc/ssh/sshd_config

if [ "$SEBPI_LOCALE_GEN" == 0 ]; then
	SEBPI_LOCALE="en_GB.UTF-8"
	sudo locale-gen "$SEBPI_LOCALE"
	sudo update-locale LC_ALL=$SEBPI_LOCALE LANG=$SEBPI_LOCALE

	sudo touch "$SEBPI_LOCALE_GEN_FILE"
fi

sudo mkdir -p /etc/pihole
sudo rm /etc/pihole/setupVars.conf
sudo touch /etc/pihole/setupVars.conf
sudo sh -c 'echo "PIHOLE_INTERFACE=eth0" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "IPV4_ADDRESS=192.168.1.2/24" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "IPV6_ADDRESS=" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "PIHOLE_DNS_1=1.1.1.1" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "PIHOLE_DNS_2=1.0.0.1" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "QUERY_LOGGING=true" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "INSTALL_WEB_SERVER=true" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "INSTALL_WEB_INTERFACE=true" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "LIGHTTPD_ENABLED=true" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "BLOCKING_ENABLED=true" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "WEBPASSWORD=" >> /etc/pihole/setupVars.conf'

cd /home/pi
curl -sSL https://install.pi-hole.net > install_pihole.sh
chmod +x install_pihole.sh
sudo sh -c './install_pihole.sh --unattended'
rm install_pihole.sh
echo | pihole -a -p

if [ ! -z "$PUSHBULLET_API_KEY" ]; then
	if ! grep -q "$PUSHBULLET_API_KEY" "/etc/rc.local"; then
		# send a pushbullet notification on login
		sudo sed -i '$i'"$(echo "curl -s -u $PUSHBULLET_API_KEY: https://api.pushbullet.com/v2/pushes -d type=note -d title=Raspberry\\\ Pi -d body=Raspberry\\\ Pi\\\ is\\\ up! > /dev/null")" /etc/rc.local
	fi
fi

if [ "$SEBPI_INSTALLED" == 0 ]; then
	# https://www.zdnet.com/article/raspberry-pi-extending-the-life-of-the-sd-card/
	# sudo sh -c 'echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0" >> /etc/fstab'
	# sudo sh -c 'echo "tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=30m 0 0" >> /etc/fstab'
	# sudo sh -c 'echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,mode=0755,size=100m 0 0" >> /etc/fstab'
	# sudo sh -c 'echo "tmpfs /var/run tmpfs defaults,noatime,nosuid,mode=0755,size=2m 0 0" >> /etc/fstab'

	# disable front LEDs on login
	sudo sed -i '$i'"$(echo "sudo sh -c 'echo 0 > /sys/class/leds/led0/brightness'")" /etc/rc.local
	sudo sed -i '$i'"$(echo "sudo sh -c 'echo 0 > /sys/class/leds/led1/brightness'")" /etc/rc.local

	sudo $SEBPI_UPDATE_SCRIPT

	# install speedtest-cli
	wget -O /home/pi/speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py
	chmod +x /home/pi/speedtest-cli
	sudo mv -f /home/pi/speedtest-cli /usr/local/bin/

	# install namebench
	sudo apt-get install namebench -y

	sudo touch "$SEBPI_INSTALLED_FILE"
fi

# disable front LEDs immediately
sudo sh -c 'echo 0 > /sys/class/leds/led0/brightness'
sudo sh -c 'echo 0 > /sys/class/leds/led1/brightness'
