# Developing www/chromium on OpenBSD

Information is current as of Jan 2021.

Chromium is one of the largest and slowest to build ports on OpenBSD.

## Time

A modest 2013-era laptop takes about a day to build optimized chromium
from scratch with MAKE_JOBS=4 on 6.8-current.

## RAM

amd64 builds comfortably in 16G. i386 can manage with 2G in 30 hours
(but the resulting binary won't execute). arm64 currently fails given
128G (Fatal process out of memory: Failed to reserve memory for new V8
Isolate)

## Disk

On amd64 somewhere around 60G will be needed to build a component
debug flavor. An ordinary optimized build takes mere 11G.

## Development

`FLAVOR=component` speeds up `make rebuild`. This is critical for any
sane development iteration.

The pobj directory after `make build` contains a viable browser which
can be launched from `out/Release` directory with `--no-sandbox
--disable-unveil`. A `FLAVOR=component` binary additionally needs
`LD_LIBRARY_PATH=$path_to_pobj_chromium/Release`.

`PATCHORIG=.orig.port` in chromimum Makefile means that patch backup
files don't have the ordinary `.orig` suffix. This might be puzzling
the first time.
