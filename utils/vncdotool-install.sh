#!/bin/bash

#install packages required
sudo yum install -y python-devel platform-python-devel python-pip python3-pip --setopt=strict=0
PIP=$(which --skip-alias --skip functions pip 2>/dev/null)
which pip &>/dev/null || PIP=$(which --skip-alias --skip functions pip3 2>/dev/null)

sudo $PIP --default-timeout=720 install --upgrade pip
sudo $PIP --default-timeout=720 install --upgrade setuptools
sudo $PIP --default-timeout=720 install vncdotool service_identity
