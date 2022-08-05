#!/bin/sh
# llcolor.sh

T='RGB'
fgs_a=('    m' '   1m' '  30m' '1;30m' '  31m' '1;31m' '  32m' '1;32m' '  33m' '1;33m' '  34m' '1;34m' '  35m' '1;35m' '  36m' '1;36m' '  37m' '1;37m')
echo
echo -e "01234567012345670123456701234567012345670123456701234567012345670123456701234567"
echo -e "--------------------------------------------------------------------------------"
echo    "fg \ bg | no-bg |  40m  |  41m  |  42m  |  43m  |  44m  |  45m  |  46m  |  47m |"
echo -e "--------+-------+-------+-------+-------+-------+-------+-------+-------+-------"
for fgs in "${fgs_a[@]}"
do
        fg=${fgs// /}
        echo -en " $fgs  |\033[$fg  $T\033[0m  "
        for bg in 40m 41m 42m 43m 44m 45m 46m 47m
        do
                echo -en " \033[$fg\033[$bg  $T  \033[0m";
        done
        echo
done
echo

_ansi()       { read FB E <<<"${1/,/ }"; echo -e "${FB:-_} ${E:-_}: \e[${FB}m${*:2}\e[${E}m"; }
ansi()        { _ansi '' "$@"; }
ans0()        { _ansi 0 "$@"; }
bold()        { _ansi 1 "$@"; }
dimn()        { _ansi 2 "$@"; }
italic()      { _ansi 3 "$@"; }
underline()   { _ansi 4 "$@"; }
strikethr()   { _ansi 9 "$@"; }
red()         { _ansi 31 "$@"; }
green()       { _ansi 32 "$@"; }
yellow()      { _ansi 33 "$@"; }
blue()        { _ansi 34 "$@"; }
hred()        { _ansi "1;31" "$@"; }
hgreen()      { _ansi "1;32" "$@"; }
hyellow()     { _ansi "1;33" "$@"; }
hblue()       { _ansi "1;34" "$@"; }

ansi ansi {a..z} {1..9}
ans0 ans0 {a..z} {1..9}
bold bold {a..z} {1..9}
dimn dimn {a..z} {1..9}
italic italic {a..z} {1..9}
underline underline {a..z} {1..9}
strikethr strikethr {a..z} {1..9}
red red {a..z} {1..9}
green green {a..z} {1..9}
yellow yellow {a..z} {1..9}
blue blue {a..z} {1..9}
hred hred {a..z} {1..9}
hgreen hgreen {a..z} {1..9}
hyellow hyellow {a..z} {1..9}
hblue hblue {a..z} {1..9}
