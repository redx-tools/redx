# Installing redx

## Recommended: Docker


Ensure you have docker installed and that you can run it via the current user. 
See https://docs.docker.com/engine/install/linux-postinstall/ for instructions 
on running Docker as a non-root user. 

We provide a wrapper `dredx` to our tool `redx`, which runs `redx` inside a 
docker container, and a wrapper `dregtest`, which likewise runs our 
regression suite `regtest` inside the container. The wrappers build the 
docker image on first use (~30-40 minutes; later runs reuse the cached 
image). To check the installation, run one example:

```bash
./dredx proverif toys/sign-then-encode
```

The outputs (`proverif-model.pv`, `proverif-R.os`, etc.) appear under
`examples/toys/sign-then-encode/`. See the [README](README.md) for running 
individual examples and the full regression suite.

---

## Local Installation

This section describes the instructions if you want a local, non-docker 
installation.

### 1. Install opam

`opam init` builds the OCaml compiler from source, so you need a C toolchain
(`cc`/`gcc` and `make`) on your system first:

```bash
# Debian/Ubuntu
sudo apt-get install build-essential
```

Then follow the instructions at https://opam.ocaml.org/doc/Install.html and run:

```bash
opam init
eval $(opam env)
```

### 2. Install core toolchain

```bash
opam install ocaml dune menhir yojson
```

### 3. Install backends

#### ProVerif

```bash
opam install proverif
```

If this fails, you may need GTK2 system libraries first:

```bash
# Debian/Ubuntu
sudo apt-get install pkg-config libgtk2.0-dev
# then retry opam install proverif
```

Alternatively, download the sources from 
https://bblanche.gitlabpages.inria.fr/proverif/ and build proverif yourself.


#### Tamarin

We need to apply a small patch to the official Tamarin source code. The official
version provides a `--no-compress` command-line argument but still compresses the
attack trace in the produced .dot/.json file. The compressed attack trace loses 
the attacker recipe information, which is crucial for redx's reduction 
reconstruction step. 

Thus, the Tamarin sources are vendored in `vendors/` and the instructions 
below apply our patch that wires in the `--no-compress` flag into Tamarin's 
batch processing mode.

Building Tamarin needs [Haskell Stack](https://docs.haskellstack.org/en/stable/install_and_upgrade/): 
```bash
curl -sSL https://get.haskellstack.org/ | sh
```

In addition, it needs Maude at runtime:

```bash
# Debian/Ubuntu
sudo apt-get install maude
```

Now build our patched Tamarin version from source. We patch a copy under
`build/` rather than the vendored source, so the vendored tree stays identical
to upstream Tamarin. The binary is installed into `vendors/tamarin-prover/out/`
rather than system-wide, so it can't clash with any `tamarin-prover` already on
your `PATH`. Run this from the `redx/` root:
```bash
mkdir -p build && cp -a vendors/tamarin-prover build/
cd build/tamarin-prover
patch -p1 < ../../vendors/patches/0001-output-traces-honor-no-compress.patch
stack setup --install-ghc
stack install --local-bin-path ../../vendors/tamarin-prover/out
```

The `./redx` wrapper points the `tamarin` backend at this build automatically
(via the `REDX_TAMARIN` environment variable).

#### Tamarin-Unchained

Tamarin-Unchained is a research variant of Tamarin with support for user-defined
AC operators, introduced in:

> Dreier, Klein, Kremer. *TAMARIN Unchained: Handling User-Defined AC Operators*.
> https://hal.science/hal-05196126v1/document

Its source is included in `vendors/tamarin-unchained/` (GPL-3.0). Build it
with the same patch step as for Tamarin above (from the `redx/` root):

```bash
mkdir -p build && cp -a vendors/tamarin-unchained build/
cd build/tamarin-unchained
patch -p1 < ../../vendors/patches/0001-output-traces-honor-no-compress.patch
stack setup --install-ghc
stack install --local-bin-path ../../vendors/tamarin-unchained/out
```

As above, the `tamarin-unchained` backend finds this build automatically via
the `REDX_TAMARIN_UNCHAINED` environment variable.

### 4. Build redx

From the `redx/` directory:

```bash
dune build
```

## Checking the installation

From the `redx/` directory:

```bash
./redx proverif toys/sign-then-encode
```

The outputs (`proverif-model.pv`, `proverif-R.os`, etc.) appear under
`examples/toys/sign-then-encode/`. See the [README](README.md) for running
examples and the regression suite.
