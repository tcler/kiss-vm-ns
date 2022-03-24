#!/bin/sh
#verified on rhel4 rhel5 rhel-6 rhel-7 rhel-8 rhel-9

ip -o addr | awk '!/^[0-9]*: ?lo|link\// {gsub("/", " "); print $2" "$4}'
