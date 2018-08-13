#!/bin/bash

SEBPI_INSTALLED_FILE=/boot/sebpi.installed
SEBPI_INSTALLED=0
if [ -e "$SEBPI_INSTALLED_FILE" ]; then
	echo "This is not the first time this script is run, ignoring some one-time settings."
	SEBPI_INSTALLED=1
fi

sudo apt-get update -y && sudo apt-get dist-upgrade -y && sudo apt-get autoremove -y

sudo mkdir -p /etc/pihole
sudo rm /etc/pihole/setupVars.conf
sudo touch /etc/pihole/setupVars.conf
sudo sh -c 'echo "WEBPASSWORD=" > /etc/pihole/setupVars.conf'
sudo sh -c 'echo "PIHOLE_INTERFACE=eth0" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "IPV4_ADDRESS=192.168.1.2/24" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "IPV6_ADDRESS=" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "PIHOLE_DNS_1=1.1.1.1" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "PIHOLE_DNS_2=8.8.8.8" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "QUERY_LOGGING=true" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "INSTALL_WEB_SERVER=true" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "INSTALL_WEB_INTERFACE=true" >> /etc/pihole/setupVars.conf'
sudo sh -c 'echo "LIGHTTPD_ENABLED=true" >> /etc/pihole/setupVars.conf'

cd /home/pi
curl -sSL https://install.pi-hole.net > install_pihole.sh
chmod +x install_pihole.sh
sudo ./install_pihole.sh --unattended
rm install_pihole.sh
echo | pihole -a -p

if [ "$SEBPI_INSTALLED" == 0 ]; then
	# https://www.zdnet.com/article/raspberry-pi-extending-the-life-of-the-sd-card/
	# sudo sh -c 'echo "tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0" >> /etc/fstab'
	# sudo sh -c 'echo "tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=30m 0 0" >> /etc/fstab'
	# sudo sh -c 'echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,mode=0755,size=100m 0 0" >> /etc/fstab'
	# sudo sh -c 'echo "tmpfs /var/run tmpfs defaults,noatime,nosuid,mode=0755,size=2m 0 0" >> /etc/fstab'

	# disable front LEDs on start
	sudo sed -i '$i'"$(echo "sudo sh -c 'echo 0 > /sys/class/leds/led0/brightness'")" /etc/rc.local
	sudo sed -i '$i'"$(echo "sudo sh -c 'echo 0 > /sys/class/leds/led1/brightness'")" /etc/rc.local

	# enable auto login of user pi
	# sudo systemctl set-default multi-user.target
	# sudo sed /etc/systemd/system/autologin@.service -i -e "s#^ExecStart=-/sbin/agetty --autologin [^[:space:]]*#ExecStart=-/sbin/agetty --autologin pi#"
	# sudo ln -fs /etc/systemd/system/autologin@.service /etc/systemd/system/getty.target.wants/getty@tty1.service

	# install speedtest-cli
	wget -O /home/pi/speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py
	chmod +x /home/pi/speedtest-cli
	sudo mv -f /home/pi/speedtest-cli /usr/local/bin/

	sudo touch "$SEBPI_INSTALLED_FILE"
fi

sudo sh -c 'echo 0 > /sys/class/leds/led0/brightness'
sudo sh -c 'echo 0 > /sys/class/leds/led1/brightness'
