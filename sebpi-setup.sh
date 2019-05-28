#!/bin/bash

function confirm() {
    # call with a prompt string or use a default
    read -r -p "${1:-Are you sure?} [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

function install_log2ram() {
	if [ -e "/usr/local/bin/uninstall-log2ram.sh" ]; then
		chmod +x /usr/local/bin/uninstall-log2ram.sh && sudo /usr/local/bin/uninstall-log2ram.sh
	fi

	curl -Lo log2ram.tar.gz https://github.com/azlux/log2ram/archive/master.tar.gz
	tar xf log2ram.tar.gz
	cd log2ram-master
	chmod +x install.sh && sudo ./install.sh
	cd ..
	rm -r log2ram-master
}

function install_speedtest() {
	wget -O speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py
	chmod +x speedtest-cli
	sudo mv -f speedtest-cli /usr/local/bin/
}

function install_pihole() {
	sudo mkdir -p /etc/pihole
	sudo rm -f /etc/pihole/setupVars.conf
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

	cd /home/pi || exit 1

	curl -sSL https://install.pi-hole.net > install_pihole.sh
	chmod +x install_pihole.sh
	sudo sh -c './install_pihole.sh --unattended'
	sudo sh -c './install_pihole.sh --unattended' # run script twice because it fails at every first install and succeeds at 2nd - don't know why yet
	rm install_pihole.sh
	echo | pihole -a -p
}

PUSHBULLET_API_KEY="$1"
if [ -z "$PUSHBULLET_API_KEY" ]; then
    confirm "No PushBullet API key was provided in parameter. Continue?" || exit 1
fi

SEBPI_UPDATE_SCRIPT=/boot/sebpi-update.sh
SEBPI_INSTALLED_FILE=/boot/sebpi.installed
SEBPI_LOCALE_GEN_FILE=/boot/sebpi.locale.gen

if [ ! -e "$SEBPI_LOCALE_GEN_FILE" ]; then
	# Fix locale issues on Debian
	sudo sed -i 's/^AcceptEnv.*/#AcceptEnv LANG LC_*/' /etc/ssh/sshd_config

	local SEBPI_LOCALE="en_GB.UTF-8"
	export LANGUAGE=$SEBPI_LOCALE
	sudo locale-gen "$SEBPI_LOCALE"
	sudo update-locale LC_ALL=$SEBPI_LOCALE LANG=$SEBPI_LOCALE

	sudo touch "$SEBPI_LOCALE_GEN_FILE"
fi

# check DNS is working before attempting install
until ping -c1 www.google.com
do
    sudo sh -c 'echo "nameserver 1.1.1.1" > /etc/resolv.conf' # temp fix if DNS fails, note that resolv.conf will be overriden during pihole install
    sleep 1
done

if [ -n "$PUSHBULLET_API_KEY" ]; then
	if ! grep -q "$PUSHBULLET_API_KEY" "/etc/rc.local"; then
		# send a pushbullet notification on login
		sudo sed -i '$i'"$(echo "curl -s -u $PUSHBULLET_API_KEY: https://api.pushbullet.com/v2/pushes -d type=note -d title=Raspberry\\\ Pi -d body=Raspberry\\\ Pi\\\ is\\\ up! > /dev/null")" /etc/rc.local
		curl -s -u $PUSHBULLET_API_KEY: https://api.pushbullet.com/v2/pushes -d type=note -d title="Raspberry Pi" -d body="PushBullet enabled!" > /dev/null
		# TODO - use PushBullet to send healthcheck warnings: low free space / high CPU / internet lost
	fi
fi

if [ ! -e "$SEBPI_INSTALLED_FILE" ]; then
	install_log2ram

	# disable physical board LEDs on login
	sudo sed -i '$i'"$(echo "sudo sh -c 'echo 0 > /sys/class/leds/led0/brightness'")" /etc/rc.local
	sudo sed -i '$i'"$(echo "sudo sh -c 'echo 0 > /sys/class/leds/led1/brightness'")" /etc/rc.local

	sudo sh -c "$SEBPI_UPDATE_SCRIPT"

	install_speedtest

	sudo touch "$SEBPI_INSTALLED_FILE"
fi

install_pihole

# disable physical board LEDs immediately
sudo sh -c 'echo 0 > /sys/class/leds/led0/brightness'
sudo sh -c 'echo 0 > /sys/class/leds/led1/brightness'

if [ -n "$PUSHBULLET_API_KEY" ]; then
    curl -s -u $PUSHBULLET_API_KEY: https://api.pushbullet.com/v2/pushes -d type=note -d title="Raspberry Pi" -d body="sebpi setup finished!" > /dev/null
fi
