# Native dependencies

## LibreDWG

[GNU LibreDWG](https://www.gnu.org/software/libredwg/) 0.13.3 is a git
submodule at `libredwg/`, from
[LibreDWG/libredwg](https://github.com/LibreDWG/libredwg). The FanCAD build
hook compiles it as a static PIC library and links `libredwg.a` into
`libfancad_io`.

```bash
git submodule update --init --recursive
```

`tool/setup_libredwg.sh` is a wrapper for the same command.
