#!/bin/bash

yum install -y autoconf gcc make netpbm-progs
git clone https://github.com/tcler/gocr
(
cd gocr
./configure && make && make install
)
