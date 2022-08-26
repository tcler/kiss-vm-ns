#!/bin/bash

procf=/proc/fs/fscache/stats
if [[ ! -f $procf ]]; then
	echo "[Error] proc file '$procf' doesn't exit!"
	exit 1
fi

: <<'EOF'
FS-Cache statistics
Cookies: n=0 v=0 vcol=0 voom=0
Acquire: n=0 ok=0 oom=0
LRU    : n=0 exp=0 rmv=0 drp=0 at=0
Invals : n=0
Updates: n=0 rsz=0 rsn=0
Relinqs: n=0 rtr=0 drop=0
NoSpace: nwr=0 ncr=0 cull=0
IO     : rd=0 wr=0
RdHelp : RA=0 RP=0 WB=0 WBZ=0 rr=0 sr=0
RdHelp : ZR=0 sh=0 sk=0
RdHelp : DL=0 ds=0 df=0 di=0
RdHelp : RD=0 rs=0 rf=0
RdHelp : WR=0 ws=0 wf=0
EOF

fcontent=$(< $procf)
eval $(echo "$fcontent"|awk -F: '/Cookies/ {print $2}')
echo "cookies-data-storage: $n  #Number of data storage cookies allocated"
echo "cookies-volume-index: $v  #Number of volume index cookies allocated"
echo "cookies-vcol: $vcol  #Number of volume index key collisions"
echo "cookies-voom: $voom  #Number of OOM events when allocating volume cookies"

eval $(echo "$fcontent"|awk -F: '/Acquire/ {print $2}')
echo "acquire-seen: $n    #Number of acquire cookie requests seen"
echo "acquire-ok:   $ok   #Number of acq reqs succeeded"
echo "acquire-oom:  $oom  #Number of acq reqs failed on ENOMEM"

eval $(echo "$fcontent"|awk -F: '/LRU/ {print $2}')
echo "LRU-cookies-cur: $n    #Number of cookies currently on the LRU"
echo "LRU-cookies-exp: $exp  #Number of cookies expired off of the LRU"
echo "LRU-cookies-rmv: $rmv  #Number of cookies removed from the LRU"
echo "LRU-cookies-drp: $drp  #Number of LRU'd cookies relinquished/withdrawn"
echo "LRU-cookies-at:  $at   #Time till next LRU cull (jiffies)"

eval $(echo "$fcontent"|awk -F: '/Invals/ {print $2}')
echo "invalidations: $n  #Number of invalidations"

eval $(echo "$fcontent"|awk -F: '/Updates/ {print $2}')
echo "updates-seen: $n  #Number of update cookie requests seen"
echo "updates-resize: $rsz  #Number of resize requests"
echo "updates-skipped-resize: $rsn  #Number of skipped resize requests"

eval $(echo "$fcontent"|awk -F: '/Relinqs/ {print $2}')
echo "relinquish-seen: $n  #Number of relinquish cookie requests seen"
echo "relinquish-retire: $rtr  #Number of rlq reqs with retire=true"
echo "relinquish-drop: $drop  #Number of cookies no longer blocking re-acquisition"

eval $(echo "$fcontent"|awk -F: '/NoSpace/ {print $2}')
echo "nospace-nwr: $nwr  #Number of write requests refused due to lack of space"
echo "nospace-ncr: $ncr  #Number of create requests refused due to lack of space"
echo "nospace-cull: $cull  #Number of objects culled to make space"

eval $(echo "$fcontent"|awk -F: '/IO/ {print $2}')
echo "io-rd: $rd  #Number of read operations in the cache"
echo "io-wr: $wr  #Number of write operations in the cache"

eval $(echo "$fcontent"|awk -F: '/RdHelp/ {print $2}')
echo "io-read-success: $rs  #Number of read operations in the cache success"
echo "io-read-fail: $rf  #Number of read operations in the cache fail"
echo "io-write-success: $ws  #Number of write operations in the cache success"
echo "io-write-fail: $wf  #Number of write operations in the cache fail"

