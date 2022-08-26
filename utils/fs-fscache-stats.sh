#!/bin/bash

procf=/proc/fs/fscache/stats
if [[ ! -f $procf ]]; then
	echo "[Error] proc file '$procf' doesn't exit!"
	exit 1
fi

: <<'OLD'
FS-Cache statistics
Cookies: idx=14 dat=0 spc=0
Objects: alc=0 nal=0 avl=0 ded=0
ChkAux : non=0 ok=0 upd=0 obs=0
Pages  : mrk=0 unc=0
Acquire: n=14 nul=0 noc=0 ok=14 nbf=0 oom=0
Lookups: n=0 neg=0 pos=0 crt=0 tmo=0
Invals : n=0 run=0
Updates: n=0 nul=0 run=0
Relinqs: n=13 nul=0 wcr=0 rtr=0
AttrChg: n=0 ok=0 nbf=0 oom=0 run=0
Allocs : n=0 ok=0 wt=0 nbf=0 int=0
Allocs : ops=0 owt=0 abt=0
Retrvls: n=0 ok=0 wt=0 nod=0 nbf=0 int=0 oom=0
Retrvls: ops=0 owt=0 abt=0
Stores : n=0 ok=0 agn=0 nbf=0 oom=0
Stores : ops=0 run=0 pgs=0 rxd=0 olm=0
VmScan : nos=0 gon=0 bsy=0 can=0 wt=0
Ops    : pend=0 run=0 enq=0 can=0 rej=0
Ops    : ini=0 dfr=0 rel=0 gc=0
CacheOp: alo=0 luo=0 luc=0 gro=0
CacheOp: inv=0 upo=0 dro=0 pto=0 atc=0 syn=0
CacheOp: rap=0 ras=0 alp=0 als=0 wrp=0 ucp=0 dsp=0
CacheEv: nsp=0 stl=0 rtr=0 cul=0
OLD

: <<'NEW'
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
NEW

fcontent=$(< $procf)
if echo "$fcontent" | grep -q ^IO; then
	eval $(echo "$fcontent"|awk -F: '/Cookies/ {print $2}')
	echo -e "cookies-data-storage: $n    \t#Number of data storage cookies allocated"
	echo -e "cookies-volume-index: $v    \t#Number of volume index cookies allocated"
	echo -e "cookies-vcol: $vcol    \t#Number of volume index key collisions"
	echo -e "cookies-voom: $voom    \t#Number of OOM events when allocating volume cookies"
	echo

	eval $(echo "$fcontent"|awk -F: '/Acquire/ {print $2}')
	echo -e "acquire-seen: $n    \t#Number of acquire cookie requests seen"
	echo -e "acquire-ok: $ok    \t#Number of acq reqs succeeded"
	echo -e "acquire-oom: $oom    \t#Number of acq reqs failed on ENOMEM"
	echo

	eval $(echo "$fcontent"|awk -F: '/LRU/ {print $2}')
	echo -e "LRU-cookies-cur: $n    \t#Number of cookies currently on the LRU"
	echo -e "LRU-cookies-exp: $exp    \t#Number of cookies expired off of the LRU"
	echo -e "LRU-cookies-rmv: $rmv    \t#Number of cookies removed from the LRU"
	echo -e "LRU-cookies-drp: $drp    \t#Number of LRU'd cookies relinquished/withdrawn"
	echo -e "LRU-time-till-next: $at    \t#Time till next LRU cull (jiffies)"
	echo

	eval $(echo "$fcontent"|awk -F: '/Invals/ {print $2}')
	echo -e "invalidations: $n    \t#Number of invalidations"
	echo

	eval $(echo "$fcontent"|awk -F: '/Updates/ {print $2}')
	echo -e "updates-seen: $n    \t#Number of update cookie requests seen"
	echo -e "updates-resize: $rsz    \t#Number of resize requests"
	echo -e "updates-skipped-resize: $rsn    \t#Number of skipped resize requests"
	echo

	eval $(echo "$fcontent"|awk -F: '/Relinqs/ {print $2}')
	echo -e "relinquish-seen: $n    \t#Number of relinquish cookie requests seen"
	echo -e "relinquish-retire: $rtr    \t#Number of rlq reqs with retire=true"
	echo -e "relinquish-drop: $drop    \t#Number of cookies no longer blocking re-acquisition"
	echo

	eval $(echo "$fcontent"|awk -F: '/NoSpace/ {print $2}')
	echo -e "nospace-nwr: $nwr    \t#Number of write requests refused due to lack of space"
	echo -e "nospace-ncr: $ncr    \t#Number of create requests refused due to lack of space"
	echo -e "nospace-cull: $cull    \t#Number of objects culled to make space"
	echo

	eval $(echo "$fcontent"|awk -F: '/IO/ {print $2}')
	echo -e "io-read: $rd    \t#Number of read operations in the cache"
	echo -e "io-write: $wr    \t#Number of write operations in the cache"
	echo

	eval $(echo "$fcontent"|awk -F: '/RdHelp/ {print $2}')
	echo -e "io-read-success: $rs    \t#Number of read operations in the cache success"
	echo -e "io-read-fail: $rf    \t#Number of read operations in the cache fail"
	echo -e "io-write-success: $ws    \t#Number of write operations in the cache success"
	echo -e "io-write-fail: $wf    \t#Number of write operations in the cache fail"
else
	eval $(echo "$fcontent"|awk -F: '/Cookies/ {print $2}')
	echo -e "cookies-index: $idx    \t#Number of index cookies allocated"
	echo -e "cookies-data-storage: $dat    \t#Number of data storage cookies allocated"
	echo -e "cookies-special: $spc    \t#Number of special cookies allocated"
	echo

	eval $(echo "$fcontent"|awk -F: '/Objects/ {print $2}')
	echo -e "objects-allocated: $alc    \t#Number of objects allocated"
	echo -e "objects-allocte-fail: $nal    \t#Number of object allocation failures"
	echo -e "objects-available: $avl    \t#Number of objects that reached the available state"
	echo -e "objects-dead: $ded    \t#Number of objects that reached the dead state"
	echo

	eval $(echo "$fcontent"|awk -F: '/ChkAux/ {print $2}')
	echo -e "object-chk-non: $non    \t#Number of objects that didn't have a coherency check"
	echo -e "object-chk-ok: $ok    \t#Number of objects that passed a coherency check"
	echo -e "object-chk-need-update: $upd    \t#Number of objects that needed a coherency data update"
	echo -e "object-chk-obsolete: $obs    \t#Number of objects that were declared obsolete"
	echo

	eval $(echo "$fcontent"|awk -F: '/Pages/ {print $2}')
	echo -e "pages-cached: $mrk    \t#Number of pages marked as being cached"
	echo -e "pages-uncache: $unc    \t#Number of uncache page requests seen"
	echo

	eval $(echo "$fcontent"|awk -F: '/Acquire/ {print $2}')
	echo -e "acquire-seen: $n    \t#Number of acquire cookie requests seen"
	echo -e "acquire-null-parent: $nul    \t#Number of acq reqs given a NULL parent"
	echo -e "acquire-no-cache: $noc    \t#Number of acq reqs rejected due to no cache available"
	echo -e "acquire-ok: $ok    \t#Number of acq reqs succeeded"
	echo -e "acquire-error: $nbf    \t#Number of acq reqs rejected due to error"
	echo -e "acquire-oom: $oom    \t#Number of acq reqs failed on ENOMEM"
	echo

	eval $(echo "$fcontent"|awk -F: '/Lookups/ {print $2}')
	echo -e "lookups-calls: $n    \t#Number of lookup calls made on cache backends"
	echo -e "lookups-negative: $neg    \t#Number of negative lookups made"
	echo -e "lookups-positive: $pos    \t#Number of positive lookups made"
	echo -e "lookups-obj-created: $crt    \t#Number of objects created by lookup"
	echo -e "lookups-timeout: $tmo    \t#Number of lookups timed out and requeued"
	echo

	eval $(echo "$fcontent"|awk -F: '/Invals/ {print $2}') 2>/dev/null && {
	echo -e "invalidations: $n    \t#Number of invalidations"
	echo -e "invalidations-run: $run    \t#Number of invalidations: run"
	echo; }

	eval $(echo "$fcontent"|awk -F: '/Updates/ {print $2}')
	echo -e "updates-seen: $n    \t#Number of update cookie requests seen"
	echo -e "updates-null-parent: $nul    \t#Number of upd reqs given a NULL parent"
	echo -e "updates-run: $run    \t#Number of upd reqs granted CPU time"
	echo

	eval $(echo "$fcontent"|awk -F: '/Relinqs/ {print $2}')
	echo -e "relinquish-seen: $n    \t#Number of relinquish cookie requests seen"
	echo -e "relinquish-null-parent: $nul    \t#Number of rlq reqs given a NULL parent"
	echo -e "relinquish-wait-create: $wcr    \t#Number of rlq reqs waited on completion of creation"
	echo

	eval $(echo "$fcontent"|awk -F: '/AttrChg/ {print $2}')
	echo -e "attr-change-seen: $n    \t#Number of attribute changed requests seen"
	echo -e "attr-change-queued: $ok    \t#Number of attr changed requests queued"
	echo -e "attr-change-nobufs: $nbf    \t#Number of attr changed rejected -ENOBUFS"
	echo -e "attr-change-nomem: $oom    \t#Number of attr changed failed -ENOMEM"
	echo -e "attr-change-run: $run    \t#Number of attr changed ops given CPU time"
	echo

	eval $(echo "$fcontent"|awk -F: '/Allocs/ {print $2}')
	echo -e "alloc-seen: $n    \t#Number of allocation requests seen"
	echo -e "alloc-success: $ok    \t#Number of successful alloc reqs"
	echo -e "alloc-wait: $wt    \t#Number of alloc reqs that waited on lookup completion"
	echo -e "alloc-nobufs: $nbf    \t#Number of alloc reqs rejected -ENOBUFS"
	echo -e "alloc-restartsys: $int    \t#Number of alloc reqs aborted -ERESTARTSYS"
	echo -e "alloc-submitted: $ops    \t#Number of alloc reqs submitted"
	echo -e "alloc-wait-cpu: $owt    \t#Number of alloc reqs waited for CPU time"
	echo -e "alloc-obj-death: $abt    \t#Number of alloc reqs aborted due to object death"
	echo

	eval $(echo "$fcontent"|awk -F: '/Retrvls/ {print $2}')
	echo -e "retrieval-seen: $n    \t#Number of retrieval (read) requests seen"
	echo -e "retrieval-success: $ok    \t#Number of successful retr reqs"
	echo -e "retrieval-wait: $wt    \t#Number of retr reqs that waited on lookup completion"
	echo -e "retrieval-nodata: $nod    \t#Number of retr reqs returned -ENODATA"
	echo -e "retrieval-nobufs: $nbf    \t#Number of retr reqs rejected -ENOBUFS"
	echo -e "retrieval-restartsys: $int    \t#Number of retr reqs aborted -ERESTARTSYS"
	echo -e "retrieval-nomem: $oom    \t#Number of retr reqs failed -ENOMEM"
	echo -e "retrieval-submitted: $ops    \t#Number of retr reqs submitted"
	echo -e "retrieval-wait-cpu: $owt    \t#Number of retr reqs waited for CPU time"
	echo -e "retrieval-obj-death: $abt    \t#Number of retr reqs aborted due to object death"
	echo

	eval $(echo "$fcontent"|awk -F: '/Stores/ {print $2}')
	echo -e "storage-seen: $n    \t#Number of storage (write) requests seen"
	echo -e "storage-success: $ok    \t#Number of successful store reqs"
	echo -e "storage-pending: $agn    \t#Number of store reqs on a page already pending storage"
	echo -e "storage-nobufs: $nbf    \t#Number of store reqs rejected -ENOBUFS"
	echo -e "storage-oom: $oom    \t#Number of store reqs failed -ENOMEM"
	echo -e "storage-submitted: $ops    \t#Number of store reqs submitted"
	echo -e "storage-run: $run    \t#Number of store reqs granted CPU time"
	echo -e "storage-pages: $pgs    \t#Number of pages given store req processing time"
	echo -e "storage-del-from-tree: $rxd    \t#Number of store reqs deleted from tracking tree"
	echo -e "storage-over-limit: $olm    \t#Number of store reqs over store limit"
	echo

	eval $(echo "$fcontent"|awk -F: '/VmScan/ {print $2}')
	echo -e "vmscan-no-pending-store: $nos    \t#Number of release reqs against pages with no pending store"
	echo -e "vmscan-by-time-lock-granted: $gon    \t#Number of release reqs against pages stored by time lock granted"
	echo -e "vmscan-igored: $bsy    \t#Number of release reqs ignored due to in-progress store"
	echo -e "vmscan-cancelled: $can    \t#Number of page stores cancelled due to release req"
	echo

	eval $(echo "$fcontent"|awk -F: '/Ops/ {print $2}')
	echo -e "ops-pend: $pend    \t#Number of times async ops added to pending queues"
	echo -e "ops-run: $run    \t#Number of times async ops given CPU time"
	echo -e "ops-queued: $enq    \t#Number of times async ops queued for processing"
	echo -e "ops-cancelled: $can    \t#Number of async ops cancelled"
	echo -e "ops-rejected: $rej    \t#Number of async ops rejected due to object lookup/create failure"
	echo -e "ops-init: $ini    \t#Number of async ops initialised"
	echo -e "ops-deferred: $dfr    \t#Number of async ops queued for deferred release"
	echo -e "ops-released: $rel    \t#Number of async ops released (should equal ini=N when idle)"
	echo -e "ops-gc: $gc    \t#Number of deferred-release async ops garbage collected"
	echo

	eval $(echo "$fcontent"|awk -F: '/CacheOp/ {print $2}')
	echo -e "cache-ops-alloc-obj: $alo    \t#Number of in-progress alloc_object() cache ops"
	echo -e "cache-ops-lookup-obj: $luo    \t#Number of in-progress lookup_object() cache ops"
	echo -e "cache-ops-lookup-comlete: $luc    \t#Number of in-progress lookup_complete() cache ops"
	echo -e "cache-ops-grab-obj: $gro    \t#Number of in-progress grab_object() cache ops"
	echo -e "cache-ops-update-obj: $upo    \t#Number of in-progress update_object() cache ops"
	echo -e "cache-ops-drop-obj: $dro    \t#Number of in-progress drop_object() cache ops"
	echo -e "cache-ops-put-obj: $pto    \t#Number of in-progress put_object() cache ops"
	echo -e "cache-ops-sync-cache: $syn    \t#Number of in-progress sync_cache() cache ops"
	echo -e "cache-ops-attr-chg: $atc    \t#Number of in-progress attr_changed() cache ops"
	echo -e "cache-ops-read-alloc-page: $rap    \t#Number of in-progress read_or_alloc_page() cache ops"
	echo -e "cache-ops-read-alloc-pages: $ras    \t#Number of in-progress read_or_alloc_pages() cache ops"
	echo -e "cache-ops-alloc-page: $alp    \t#Number of in-progress allocate_page() cache ops"
	echo -e "cache-ops-alloc-pages: $als    \t#Number of in-progress allocate_pages() cache ops"
	echo -e "cache-ops-write-page: $wrp    \t#Number of in-progress write_page() cache ops"
	echo -e "cache-ops-uncache-page: $ucp    \t#Number of in-progress uncache_page() cache ops"
	echo -e "cache-ops-dissociate-pages: $dsp    \t#Number of in-progress dissociate_pages() cache ops"
	echo

	eval $(echo "$fcontent"|awk -F: '/CacheEv/ {print $2}')
	echo -e "cache-event-obj-lookup-create-rej: $nsp    \t#Number of object lookups/creations rejected due to lack of space"
	echo -e "cache-event-stale-obj-del: $stl    \t#Number of stale objects deleted"
	echo -e "cache-event-obj-retired: $rtr    \t#Number of objects retired when relinquished"
	echo -e "cache-event-obj-culled: $cul    \t#Number of objects culled"
	echo
fi
