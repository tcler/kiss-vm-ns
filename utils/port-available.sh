#!/bin/bash

port_available() {
        nc $(grep -q -- '-z\>' < <(nc -h 2>&1) && echo -z) $1 $2 </dev/null &>/dev/null
}

port_available "$@"
