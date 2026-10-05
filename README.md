# redx — reduction synthesis for cryptographic proofs

This is the artifact of the paper *Automatic Synthesis of Cryptographic
Reductions Using Symbolic Verification Tools* by Prashant Agrawal, Manuel
Barbosa, Gilles Barthe, Adrien Koutsos, and Justine Sauvage. It contains
our tool, redx, and our benchmark suite.

redx synthesises cryptographic reductions. A problem consists of a
target security game G, a hard problem H, and an equational theory E.
redx compiles it so that a symbolic attack finder (ProVerif or Tamarin)
searches for an attack on H that uses a G-winner as a subroutine; from
the attack trace it reconstructs the reduction R and generates the side
conditions under which R is sound.

## Artifact Organisation

- `bin/`, `lib/` — the redx source code
- `vendors/` — our patched variants of Tamarin and Tamarin-Unchained
- `examples/` — the reduction synthesis problems (see "The examples" below)

## Installation

Follow [INSTALL.md](INSTALL.md). The recommended route is Docker (the
`./dredx` and `./dregtest` wrappers build the image on first use); the
local route covers the OCaml toolchain and the patched Tamarin builds
under `vendors/`.

## Running an example

The commands below use the Docker wrappers. Under a local
installation, substitute `./redx` for `./dredx` and `./regtest` for
`./dregtest`; the arguments are identical.

Run `./dredx <backend> <example>`, where `<backend>` is `proverif`,
`tamarin`, or `tamarin-unchained`, and `<example>` names a directory
under `examples/`, possibly nested:

```
./dredx proverif toys/sign-then-encode
./dredx proverif encrypt-then-mac/hop1
./dredx tamarin negatives/mac-then-encrypt/hop1
```

Arguments after the example are passed verbatim to the backend, e.g.
`./dredx tamarin dl-cdh --open-chains=2` to tune Tamarin's
precomputation budget (see the backend's `--help` for its flags). The
flag `--reconstruct` skips compilation and attack finding and reruns
only the reconstruction step, using the attack trace already present
in the example directory.

The outputs appear next to the games: `<backend>-R.os` is the
synthesised reduction, `<backend>-sc.th` the generated side conditions,
and `<backend>-model.*` the intermediate attack-finding model.

With a local installation, `./redx` also accepts a path outside
`examples/` as the example directory, and with no example argument
uses the current working directory (the Docker wrapper mounts only
`examples/`).

## Running the regression suite

```
./dregtest                        # the whole suite
./dregtest proverif               # one backend
./dregtest proverif basic-hash    # one backend, one example
```

For each example and backend, the suite reruns redx and diffs the
produced `R.os` and `sc.th` against the expected outputs (the
`sample-*` files in the example directory), reporting the example's
LOC and the run's wall time; the summary gives pass counts and total
time per backend. `-w[=FILE]` also writes a CSV report
(`example,backend,loc,seconds,status`) to FILE (default
`examples/report.txt`).

## The examples

Every directory under `examples/` containing a `G.os` is one reduction
synthesis problem:

- `G.os` — the target security game G
- `H.os` — the hard problem H
- `eq.th` — the equational theory E. Compilation loads none of the
  backends' built-in theories and declares every function symbol
  explicitly; the compiled models carry only E plus the equations
  compilation itself adds (the paper's Ẽ).
- `ac.txt` — associative-commutative symbols of E, one per line
  (only where needed; handled by the `tamarin-unchained` backend)
- `sample-<backend>-R.os`, `sample-<backend>-sc.th` — the expected
  reduction and side conditions. A `sample-<backend>-R.os` containing
  the single word `null` records that the backend is expected to
  report no reduction. Absent sample files mean the backend does not
  handle the problem; in particular, the Tamarin backend does not
  support indistinguishability games.
- `README.md` — what is proved, how, and how to read the results

Multi-hop proofs are directories with one subdirectory per hop
(`encrypt-then-mac/hop1`, `encrypt-then-mac/hop2`, ...) and a README
explaining how the hops assemble. The `toys/` directory collects the
minimal examples that isolate one capability of the pipeline each. The
`negatives/` directory collects problems for which no unconditional
reduction exists; see
[negatives/README.md](examples/negatives/README.md).

The problems of the paper's benchmark table map to directories as
follows. Directories not listed are additional examples beyond the
table.

| Paper                                 | Directory                          |
|---------------------------------------|------------------------------------|
| Sign-then-encode                      | `toys/sign-then-encode`            |
| Encode-then-sign                      | `toys/encode-then-sign`            |
| Encrypt-then-encode                   | `toys/encrypt-then-encode`         |
| Signature unblinding (mul)            | `toys/signature-unblinding-mul`    |
| Signature unblinding (XOR)            | `toys/signature-unblinding-xor`    |
| DL-to-CDH                             | `dl-cdh`                           |
| Basic Hash authentication             | `basic-hash/authentication`        |
| Lamport OTS EUF-1CMA (selective)      | `lamport-ots`                      |
| Signature domain extension            | `sig-domain-extension`             |
| El Gamal KEM (ROM)                    | `elgamal-kem-rom`                  |
| Multi-chal. IND-CPA (hybrid argument) | `hybrids/multi-chal-indcpa`        |
| Multi-key IND-CPA (hybrid argument)   | `hybrids/multi-key-indcpa`         |
| Encrypt-then-MAC (2 hops)             | `encrypt-then-mac/hop{1,2}`        |
| El Gamal (2 hops)                     | `elgamal/hop{1,2}`                 |
| El Gamal KEM (2 hops)                 | `elgamal-kem/hop{1,2}`             |
| Signed DH (2 hops)                    | `signed-ddh/hop{1,2}`              |
| RSA-FDH (ROM, 2 hops)                 | `rsa-fdh-rom/hop{1,2}`             |
| Homomorphic tally (Helios-style)      | `homomorphic-tally`                |
| Privacy in an abstract mixnet         | `mixnet`                           |
| Vote privacy in FOO (2 selected hops) | `foo/hop{1,2}`                     |
| Encrypt-and-MAC (negative)            | `negatives/encrypt-and-mac`        |
| Encrypt-then-MAC vs EUF-CMA (negative) | `negatives/encrypt-then-mac-euf`  |
| MAC-then-Encrypt (negative)           | `negatives/mac-then-encrypt/hop1`  |
| Untagged sig. domain ext. (negative)  | `negatives/sig-domain-extension-untagged` |

## Modelling notes

We briefly describe below some modelling notes shared by all the examples. 
Anything specific to one example is in its own README.

Game state is a table of write-once cells, addressed by a column
identifier and a row term: `store SKey[botscope()] sk` writes a cell,
`load SKey[botscope()] sk` reads it, and `empty GSign[m]` asserts it is
still unwritten. The row `botscope()` is the distinguished row ⊥ of the
paper's state discipline: it is written only by the initialisation
oracle and readable by every oracle, and holds the game's global
constants — typically the keys. Every other oracle stores only to a
single row of its own, its scope — usually its input, as in
`store GSign[m] gs` — and loads from its scope or from ⊥.

Oracles take exactly one input. An oracle needing several inputs
receives them as a nested pair and takes it apart with `fst` and `snd`;
the projection equations `fst(pair(x, y)) = x` and
`snd(pair(x, y)) = y` are therefore part of the equational theory of
every example that handles pairs. An oracle needing no input still
takes one, a dummy it ignores; well-formedness requires input
variables to be globally distinct, so the dummies are named apart —
`bot` at an init, `bot2` at a second no-input oracle.

Function symbols suffixed `_ud` ("user-defined"), such as `mul_ud` and
`xor_ud`, stand for symbols whose natural names Tamarin reserves for
its own built-ins — the bare `mul`, `xor`, `zero` are unavailable to
user declarations even though we load no built-in theory.

## Reading the outputs

The synthesised `R.os` keeps reconstruction's machine-generated names:
variables named after the attack trace (`v0`, `~M_1`) and one table
column per stored variable, named after it (`L_v0`), as in the paper's
reconstruction figure; we do not prettify generated output.

The variables of a side condition are implicitly universally
quantified. They are G's oracle input variables and name variables, one
input variable per oracle. A variable suffixed `.1`, as in `m.1`, is
the paper's daggered copy: it ranges over a second, distinct call of
the oracle that owns the variable, so `snd(gsm) != m.1` reads "the
forgery differs from every gsign query". Variables of the
initialisation oracles carry no suffix — init runs once, so every call
sees the same values.

The generated side conditions are simplified modulo E: terms are
normalised and trivially true implications are dropped. The simplifier
does no propositional or refutational reasoning beyond this, so a
condition can survive even when it repeats a conjunct of its own
premise (a tautology) or when it holds in every model of E (an
inequality whose refutation needs equational steps, as in the
signature-unblinding examples). Each example's README points out when
its conditions are vacuous in one of these ways.

## Backend invocation

Internally, redx invokes the Tamarin backends with `--no-compress`,
so that the JSON attack graph keeps the adversary deduction nodes
reconstruction reads, and with `--derivcheck-timeout=0`, which
disables Tamarin's derivation-check pre-pass. That pre-pass crashes
Maude when an equation's right-hand side is headed by a private
symbol, as in every compiled theory; only this well-formedness check
is lost, and the main solver is unaffected.
