#!/bin/bash

yum install -y autoconf gcc make
git clone https://github.com/tcler/gocr
(
cd gocr
./configure && make && make install
)
