# KIOENABLE change retrospective

[I spent a day](https://github.com/google/syzkaller/issues/906)
figuring out why OpenBSD syz-bot stopped working. The goal of this
write-up is to find a faster way to solve similar problems. I fell
victim to typical human tendencies several times along the way.

The initial symptom was [Syzkaller
Dashboard](https://syzkaller.appspot.com#openbsd) Active column
turning stale. This is the start of the outage. I have access to the
logs and so I quickly shoot an email to my co-conspirators telling them
the most specific error is syz-manager complaining about:

```
machine check: got no coverage:
```

Over-communicating is typical for me, so only later do I notice some
OpenBSD changes that seem related and there's a pending change to
syzkaller which should bring the two code bases in sync. I put the
problem on hold and wait until next morning. By then the syzkaller
change is merged and syz-bot picked it up. I decide to let it sit to
see if syz-bot self-heals. I [file an
issue](https://github.com/google/syzkaller/issues/906#issue-394706650)
because @dvyukov thinks the issue should have been caught by kernel
testing.

Yet, syz-bot remains broken and dashboard turns red due to a full day
of inactivity. I decide to look closely at the logs and notice
[syz-bot is failing to build a new
version](https://github.com/google/syzkaller/issues/906#issuecomment-450427063).

```
In file included from executor/executor.cc:312:
executor/executor_bsd.h:94:61: error: use of undeclared identifier 'KCOV_MODE_TRACE_PC'
        int kcov_mode = flag_collect_comps ? KCOV_MODE_TRACE_CMP : KCOV_MODE_TRACE_PC;
```

This is a nice and clean error. I know how to deal with
them. `ci-openbsd` build machine is running a 10 day old OpenBSD
snapshot. Luckily a very recent snapshot is available, it's only a day
old and seems just about the right age to have the OpenBSD changes I
need. [34 minutes
later](https://github.com/google/syzkaller/issues/906#issuecomment-450431396)
I have a new system that builds everything at HEAD and is still
failing.  I reach out for help to the experts (@mptre) and
simultaneously try to reduce the problem from a system failure to
something easier to understand and observe. Up until this point I have
no information about what's going under the hood, the only symptom is
`got no coverage`.

Some code searches later I narrow this down to `syz-execprog`
complaining:

```
cover enable write trace failed, mode=1 (errno 22)
```

I'm still [failing to see the arguments passed to
kernel](https://github.com/google/syzkaller/issues/906#issuecomment-450437105)
because ktrace(1) is cutting the file short. I'm guessing that it's
`KCOV_MODE_TRACE_CMP` which is not implemented in OpenBSD yet.

I'm trying to test this theory by [removing the
option](https://github.com/google/syzkaller/issues/906#issuecomment-450438202).
But, no, this is not it.

So, I'm grasping at straws, [noticing some dmesg
errors](https://github.com/google/syzkaller/issues/906#issuecomment-450441365)
then look at [file system
sizes](https://github.com/google/syzkaller/issues/906#issuecomment-450441584).
Soon I get a [complete recommendation from
@mptre](https://github.com/google/syzkaller/issues/906#issuecomment-450442338)
which would be enough for me to fully solve the problem if I had
followed it to the letter.

I do try to follow it and be as complete as I can in demonstrating
that [KCOV\_MODE\_TRACE\_PC is in fact in
sys/kcov.h](https://github.com/google/syzkaller/issues/906#issuecomment-450443919)
on the machine where builds are happening. I got unlucky here:
[KCOV\_MODE\_TRACE\_PC is introduced before the snapshot is
cut](https://github.com/openbsd/src/commit/070323f81e2a65614b8d42ced5269ee0aa6792c0)
and thus the compile error is fixed but I'm still getting errno 22.

I follow the other recommendation and [hack syzkaller code to get a
complete
ktrace](https://github.com/google/syzkaller/issues/906#issuecomment-450445224).
I see the ioctl called as `ioctl(232,KIOENABLE,0xc3e12f4cf64)` and
this totally throws me off. What's that 0xc3e12f4cf64?

I stare at the code and notice that syzkaller paths for FreeBSD and
OpenBSD have just subtly different branches. See if you catch the
difference at first glance:

```c
#if GOOS_freebsd
	if (ioctl(cov->fd, KIOENABLE, kcov_mode))
		exitf("cover enable write trace failed, mode=%d", kcov_mode);
#elif GOOS_openbsd
	if (ioctl(cov->fd, KIOENABLE, &kcov_mode))
		exitf("cover enable write trace failed, mode=%d", kcov_mode);
#endif
```

When I do, I am oh so proud of myself that [I post this
diff](https://github.com/google/syzkaller/issues/906#issuecomment-450445816)
before I finish testing it... Only to be bummed out some 30 minutes
later. Now I'm deeply frustrated. It's taken over 5 hours of fairly
intense debugging and I'm still nowhere close to the fix. I read more
code and am convinced now that OpenBSD code that I'm seeing must work
with syzkaller as written. I give it up for 5 hours.

I pick it up again and start with a fresh snapshot install from the
same Dec 27th, load the source, enable KCOV_DEBUG,
build a new kernel, build new syzkaller, run `syz-execprog` and
lo and behold `dmesg` has the smoking gun:

```
kcovioctl: 536890114: unknown command
```

This is enough even for me to re-evaluate my assumptions. I look at
what KIOENABLE is and finally notice [the definition of KIOENABLE
changed between the time the snapshot is cut and the version of kernel
that I'm
building](https://github.com/openbsd/src/commit/c4b2804f9c2807cc970c83ccfffa241cc22c25e9#diff-724c1c3a51998126507d12b96f432222).

This is the unlucky part: the compiler can't help me when the value of
KIOENABLE changes. The kernel tree uses the new value and syzkaller
uses the old one which came from the snapshot built the day before.

Manual copying from the kernel tree to `/usr/include` is enough to
finally get me out of the red. While this is a temporary hack, I don't
feel bad about it. Tomorrow's snapshot will have the same new version
of kcov.h and when I reinstall, things will be consistent. This
concludes the outage.

Now, where I could do better to be more effective. There's a fair
amount of hindsight bias here, as is typical.

* Reduce the problem sooner. While it's more fun to throw things
  and see what sticks, it's more effective to localize the problem.
  I hesitated before running syz-execprog and didn't dig
  into how I can get complete ktrace. So what that it takes an extra
  patch?
* Get maximum observability. I started enabling KCOV_DEBUG for kernel
  earlier but didn't see it through and instead of that started
  fiddling with syzkaller.
* Read expert recommendations very closely. I had the answer 8 hours
  before I found the problem the hard way.
