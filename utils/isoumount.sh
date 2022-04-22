#!/bin/bash

mp=$1
[[ -z "$mp" ]] && exit

guestunmount "$mp"
