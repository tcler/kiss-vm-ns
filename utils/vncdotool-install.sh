#!/bin/bash

#install packages required
sudo yum install -y python-devel platform-python-devel python-pip python3-pip --setopt=strict=0
PIP=pip
which pip &>/dev/null || PIP=pip3

sudo $PIP install --upgrade pip setuptools
sudo $PIP install vncdotool service_identity
