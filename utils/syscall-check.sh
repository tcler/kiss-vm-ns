
# install dependency
rpm -q gcc strace >/dev/null || {
	yum install -y gcc strace || exit
}

# check if syscall is implemented
while read snum sname; do [[ $snum != [0-9]* || $sname = vhangup ]] && continue;  echo -e '#define _GNU_SOURCE\n#include <unistd.h>\n#include <sys/syscall.h>\nint main (void) { syscall ('$snum', 0, 0, 0, 0, 0, 0, 0, 0); }'|LANG=C gcc -x c -; LANG=C timeout 2 strace -e $sname ./a.out ;  done < <(ausyscall --dump)  |& grep ENOSYS
rm -f a.out

echo

# check if there is syscall wrapper in libc
while read snum sname; do [[ $snum != [0-9]* ]] && continue;  echo -e '#define _GNU_SOURCE\n#include <unistd.h>\n#include <sys/syscall.h>\nint main (void) { syscall (SYS_'$sname', 0, 0, 0, 0, 0, 0, 0, 0); }'|LANG=C gcc -x c -;  done < <(ausyscall --dump) |& grep error:
rm -f a.out
