# Figuring out why no packet injection is happening

Having just submitted [OpenBSD network package
injection](https://github.com/google/syzkaller/pull/789) one naively
expects some coverage to start accruing. Too bad, there was no sign of
`syz_emit_ethernet` anywhere in syz-manager `/syscalls` page. So
`dvyukov` suggested running a simple syzkaller program with
`syz-execprog`. The `r.syz` contains:

```
syz_emit_ethernet(0x100, &(0x7f0000000000/0x100)=nil)

```

The requisite tools are created by `gmake host target` and can be run as:
```shell
% cd bin/openbsd_amd64
% ./syz-execprog -output r.syz
2018/11/18 11:31:55 parsed 1 programs
2018/11/18 11:31:55 code coverage           : enabled
2018/11/18 11:31:55 comparison tracing      : support is not implemented in syzkaller
2018/11/18 11:31:55 setuid sandbox          : support is not implemented in syzkaller
2018/11/18 11:31:55 namespace sandbox       : support is not implemented in syzkaller
2018/11/18 11:31:55 Android sandbox         : support is not implemented in syzkaller
2018/11/18 11:31:55 fault injection         : support is not implemented in syzkaller
2018/11/18 11:31:55 leak checking           : support is not implemented in syzkaller
2018/11/18 11:31:55 net packed injection    : support is not implemented in syzkaller
2018/11/18 11:31:55 net device setup        : support is not implemented in syzkaller
2018/11/18 11:31:55 executed programs: 0
2018/11/18 11:31:55 executing program 0:
syz_emit_ethernet(0x100, &(0x7f0000000000))

```

Aha, why is `net packed injection : support is not implemented in
syzkaller`?! Some searches later, a simple patch turns this into:
```
2018/11/18 11:34:46 net packet injection    : enabled
...
2018/11/18 11:34:46 executed programs: 0
2018/11/18 11:34:46 executing program 0:
syz_emit_ethernet(0x100, &(0x7f0000000000))
2018/11/18 11:34:46 result: failed=false hanged=false err=executor 0: EOF
tun: can't open /dev/tap0
 (errno 13)
```

Or better still with [doas(1)](https://man.openbsd.org/doas):
```
% doas ./syz-execprog -output r.syz
2018/11/18 11:35:11 parsed 1 programs
2018/11/18 11:35:11 code coverage           : enabled
...
2018/11/18 11:35:11 net packet injection    : enabled
...
2018/11/18 11:35:12 executed programs: 0
2018/11/18 11:35:12 executing program 0:
syz_emit_ethernet(0x100, &(0x7f0000000000))
```
