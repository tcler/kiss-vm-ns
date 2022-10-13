#!/bin/bash
#auth: yin-jianhong@163.com
#just for learning xfs and funny
#test pass on RHEL-7.3,RHEL-7.4,RHEL-7.9,RHEL-8.2,RHEL-8.3
#
#ref: https://xfs.org/docs/xfsdocs-xml-dev/XFS_Filesystem_Structure/tmp/en-US/html/Data_Extents.html
#ref: https://righteousit.wordpress.com/2018/05/23/xfs-part-2-inodes
#ref: https://zorrozou.github.io/docs/xfs/XFS%E6%96%87%E4%BB%B6%E7%B3%BB%E7%BB%9F%E7%BB%93%E6%9E%84.html

dev=$1
inum=$2
debug=$3
realsize=$4

ftypes[1]=fifo
ftypes[2]=chardrv
ftypes[4]=dir
ftypes[6]=blkdev
ftypes[8]=file
ftypes[10]=symlink
ftypes[12]=socket
bmxField=u3.bmx
dataForkOffset=176

inode_ver() {
	local _dev=$1
	local _inum=$2
	IFS=' ()' read ioffsetX ioffsetD < <(xfs_db -r $_dev -c "convert inode $_inum fsbyte")
	local _iver=$(dd status=none if=$_dev bs=1 skip=$((ioffsetD+4)) count=1 | hexdump -e '1/1 "%02x"')
	echo -n $((16#$_iver))
}

[[ -z "$inum" ]] && {
	echo "Usage: sudo xfs_icat <dev> <inum>" >&2
}

#INFO=$(xfs_db -r $dev -c "inode $inum" -c "type inode" -c "print core.version")
g_iver=$(inode_ver $dev $inum)
test -n "$debug" && echo "core.version = $g_iver" >&2
[[ "$g_iver" != 3 ]] && {
	bmxField=u.bmx
	dataForkOffset=100
}

_fsbno2blockno() {
	local startblock=$1
	local agblocks=$2

	[[ "${g_iver:-3}" != 3 ]] && {
		echo -n "$startblock"
		return
	}

	local agblocksB=$(echo "obase=2;$agblocks"|bc)
	local agshift=${#agblocksB}

	local startblockB=$(echo "obase=2; ibase=A; $startblock"|bc|xargs printf "%52s"|sed s/\ /0/g)
	local agnumLen=$((52-agshift))
	local agnum=$(echo "ibase=2;obase=A;${startblockB:0:${agnumLen}}"|bc)
	local relativeblock=$(echo "ibase=2;obase=A;${startblockB:${agnumLen}:${agshift}}"|bc)
	echo -n $((agnum*agblocks+relativeblock))
}
fsbno2blockno() {
	local startblock=$1
	local dev=$2

	local agblocks=
	local sbINFO=$(xfs_db -r $dev -c "inode 0" -c "type sb" -c 'print agblocks' 2>/dev/null)
	read key eq agblocks < <(grep agblocks <<<"$sbINFO")

	_fsbno2blockno $startblock $agblocks
}

inode_extent_array() {
	#ref: https://xfs.org/docs/xfsdocs-xml-dev/XFS_Filesystem_Structure/tmp/en-US/html/Data_Extents.html
	local _dev=$1
	local _inum=$2

	IFS=' ()' read ioffsetX ioffsetD < <(xfs_db -r $_dev -c "convert inode $_inum fsbyte")
	local _extentNum=$(dd status=none if=$_dev bs=1 skip=$((ioffsetD+76)) count=4 | hexdump -e '4/1 "%02x"')
	_extentNum=$((16#$_extentNum))

	local extentX= extent1B= flag= startoff= startblock= blockcount=
	for ((i=0; i<_extentNum; i++)); do
		extentX=$(dd status=none if=$_dev bs=1 skip=$((ioffsetD+dataForkOffset+i*16)) count=16 | hexdump -e '16/1 "%02X"')
		extent1B=$(echo "ibase=16;obase=2;1${extentX}"|BC_LINE_LENGTH=256 bc)
		flag=${extent1B:1:1}
		startoff=$(echo "ibase=2;obase=A;${extent1B:2:54}"|bc)
		startblock=$(echo "ibase=2;obase=A;${extent1B:56:52}"|bc)
		blockcount=$(echo "ibase=2;obase=A;${extent1B:108:21}"|bc)
		echo "${i}:[$startoff,$startblock,$blockcount,$flag]"
	done
}

inode_extent_btree() {
	local _dev=$1
	local _inum=$2

	local fsblocks
	btree_node=$(xfs_db -r $_dev -c inode\ $_inum -c p 2>/dev/null)
	read key eq fsblocks < <(egrep 'ptrs\[[0-9-]+] =' <<<"$btree_node")

	walkbtree() {
		local _dev=$1
		local nodeinfo=
		local fsblock=

		for _fsblock; do
			read idx fsblock <<<"${_fsblock/:/ }"
			nodeinfo=$(xfs_db -r $_dev -c fsblock\ $fsblock -c type\ bmapbta -c p)
			if echo "$nodeinfo"|grep -q 'level = 0'; then
				echo "$nodeinfo"|egrep '^[0-9]+:'
			else
				walkbtree $_dev $(echo "$nodeinfo"|sed -rn '/ptrs\[[0-9-]+] =/{s///; p}')
			fi
		done
	}
	walkbtree $_dev $fsblocks
}
inode_extent_btree2() {
	local _dev=$1
	local _inum=$2

	local fsbnos=
	IFS=' ()' read ioffsetX ioffsetD < <(xfs_db -r $_dev -c "convert inode $_inum fsbyte")
	local levelX=$(dd if=$_dev skip=$((ioffsetD+dataForkOffset)) bs=1 count=2 status=none|hexdump -e '2/1 "%02X"')
	local level=$((16#$levelX))
	local numX=$(dd if=$_dev skip=$((ioffsetD+dataForkOffset+2)) bs=1 count=2 status=none|hexdump -e '2/1 "%02X"')
	local num=$((16#$numX))

	local ptroffset=$((ioffsetD+dataForkOffset+4+ 8*num +24))
	for ((i=0; i< num; i++)); do
		fsblocknumX=$(dd if=$_dev skip=$((ptroffset+8*i)) bs=1 count=8 status=none|hexdump -e '8/1 "%02X"')
		fsbnos+="$((i+1)):$((16#$fsblocknumX)) "
	done

	local blocksize= agblocks=
	local sbINFO=$(xfs_db -r $_dev -c "inode 0" -c "type sb" -c 'print blocksize agblocks' 2>/dev/null)
	read key eq agblocks < <(grep agblocks <<<"$sbINFO")
	read key eq blocksize < <(grep blocksize <<<"$sbINFO")

	_treenodeinfo() {
		local _dev=$1
		local fsbno=$2
		local _agblocks=$3
		local _blocksize=$4

		local fsbnos=
		local blockno=$(_fsbno2blockno $fsbno $_agblocks)
		local offset=$((blockno*_blocksize))

		local magic=$(dd if=$_dev skip=$((offset)) bs=1 count=4 status=none|hexdump -e '4/1 "%c"')

		local levelX= level= numX= num= _fsbno=
		if [[ $magic != BMA3 ]]; then
			echo "warning: not BMA3 block" >&2
		fi

		levelX=$(dd if=$_dev skip=$((offset+4)) bs=1 count=2 status=none|hexdump -e '2/1 "%02X"')
		level=$((16#$levelX))
		numX=$(dd if=$_dev skip=$((offset+4+2)) bs=1 count=2 status=none|hexdump -e '2/1 "%02X"')
		num=$((16#$numX))
		echo "level = $level"

		if [[ $level != 0 ]]; then
			local ptroffset=$((offset+8 + 64 + num*8))

			for ((i=0; i<num; i++)); do
				_fsbno=$(dd if=$_dev skip=$((ptroffset+i*8)) bs=1 count=8 status=none|hexdump -e '8/1 "%02X"')
				fsbnos+="$((i+1)):$((16#$_fsbno)) "
			done
			echo "ptrs[1-$num] = $fsbnos"
		else
			local extentX= extentB= flag= startoff= startblock= blockcount=
			local recsoffset=$((offset+8 + 64))

			echo "recs[1-$num] ="
			for ((i=0; i<num; i++)); do
				extentX=$(dd if=$_dev skip=$((recsoffset+i*16)) bs=1 count=16 status=none|hexdump -e '16/1 "%02X"')
				extent1B=$(echo "ibase=16;obase=2;1${extentX}"|BC_LINE_LENGTH=256 bc)
				flag=${extent1B:1:1}
				startoff=$(echo "ibase=2;obase=A;${extent1B:2:54}"|bc)
				startblock=$(echo "ibase=2;obase=A;${extent1B:56:52}"|bc)
				blockcount=$(echo "ibase=2;obase=A;${extent1B:108:21}"|bc)
				echo "${i}:[$startoff,$startblock,$blockcount,$flag]"
			done
		fi
	}

	walkbtree() {
		local _dev=$1
		local agblocks=$2
		local blocksize=$3
		shift 3

		local nodeinfo=
		for _fsblock; do
			read idx _fsbno <<<"${_fsblock/:/ }"
			nodeinfo=$(_treenodeinfo $_dev $_fsbno   $agblocks $blocksize)
			if echo "$nodeinfo"|grep -q 'level = 0'; then
				echo "$nodeinfo"|egrep '^[0-9]+:'
			else
				walkbtree $_dev $agblocks $blocksize $(echo "$nodeinfo"|sed -rn '/ptrs\[[0-9-]+] =/{s///; p}')
			fi
		done
	}
	walkbtree $_dev $agblocks $blocksize $fsbnos
}

if [[ "${g_iver:-3}" = 3 ]]; then
	INFO=$(xfs_db -r $dev -c "inode $inum"                 -c "print core.format core.mode core.size" -c "version")
else
	INFO=$(xfs_db -r $dev -c "inode $inum" -c "type inode" -c "print core.format core.mode core.size" -c "version")
fi
{
read key eq coreformat desc
read key eq mode desc
read key eq fsize
read key eq fsver
} <<<"$INFO"
ftypenum=${mode%????}
ftypenum=$((8#$ftypenum))
test -n "$debug" && echo "$INFO" >&2

ftype=${ftypes[$ftypenum]}
[[ -z "$ftype" ]] && ftype="\033[41mnil\033[m"
echo -e "core.format: $coreformat, ftype: $ftype($ftypenum), fsize: $fsize, iver: $g_iver, fsver: $fsver" >&2
echo >&2

extents_cat() {
	local _dev=$1
	local _fsize=$2
	shift 2

	local agblocks=
	local sbINFO=$(xfs_db -r $_dev -c "inode 0" -c "type sb" -c 'print blocksize agblocks' 2>/dev/null)
	read key eq blocksize < <(grep blocksize <<<"$sbINFO")
	read key eq agblocks < <(grep agblocks <<<"$sbINFO")

	local left=$_fsize
	while read line; do
		for extent in $line; do
			test -n "$debug" && echo "{extexts_cat} extent: $extent" >&2
			read idx startoff startblock blockcount extentflag orig_startblock <<< "${extent//[:,\][]/ }"
			[[ $startblock =~ ^[0-9]+$ ]] || continue
			startblock=$(_fsbno2blockno $startblock $agblocks)
			extentSize=$((blockcount * blocksize))
			ddcount=$blockcount


			if [[ $extentSize -gt $left ]]; then
				ddcount=$((left/blocksize))
				mod=$((left%blocksize))

				test -n "$debug" && echo "{extexts_cat} left=$left, extentSize=$extentSize; ddcount=$ddcount, mod=$mod" >&2
				echo dd status=none if=$_dev bs=$blocksize skip=$startblock count=$ddcount >&2
				dd status=none if=$_dev bs=$blocksize skip=$startblock count=$ddcount
				[[ $mod != 0 ]] && {
					echo dd status=none if=$_dev bs=1 skip=$(((startblock+ddcount)*blocksize)) count=$mod >&2
					dd status=none if=$_dev bs=1 skip=$(((startblock+ddcount)*blocksize)) count=$mod
				}
				break 2
			else
				[[ $ddcount != 0 ]] &&
					dd status=none if=$_dev bs=$blocksize skip=$startblock count=$ddcount
			fi

			((left-=(ddcount*blocksize)))
		done
	done
}

case $coreformat in
3)
	size=4096
	[[ -n "$realsize" ]] && size=$fsize
	extents_cat $dev $size < <(inode_extent_btree2 $dev $inum)
	trap "pkill ${0##*/} &" EXIT
	;;
2)
	case $ftype in
	dir)
		extents_cat $dev $fsize < <(inode_extent_array $dev $inum) | hexdump -C;;
	file|symlink)
		extents_cat $dev $fsize < <(inode_extent_array $dev $inum);;
	esac
	;;
1)
	INFO=$(xfs_db -r $dev -c "convert inode $inum fsbyte")
	IFS=' ()' read ioffsetX ioffsetD <<<"$INFO"
	case $ftype in
	dir)
		dd status=none if=$dev bs=1 skip=$((ioffsetD+dataForkOffset)) count=$((fsize)) | hexdump -C;;
	file|symlink)
		dd status=none if=$dev bs=1 skip=$((ioffsetD+dataForkOffset)) count=$((fsize));;
	symlink2)
		xfs_db -r $dev -c "inode $inum" -c "type inode" -c "print u.symlink";;
	*)
		:;;
	esac
	;;
esac
echo >&2
exit
