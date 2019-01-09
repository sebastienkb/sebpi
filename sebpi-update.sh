#!/bin/sh

sudo apt update
sudo apt -yf dist-upgrade
sudo apt-get -y --purge autoremove
sudo apt-get autoclean
which pihole && pihole -g -up
which pihole && pihole -up
