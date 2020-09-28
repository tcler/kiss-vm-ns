#!/bin/bash

dev=$1

#why there isn't vg_active field?
pvs $dev -o vg_name,vg_uuid,lv_active --noheading|uniq
