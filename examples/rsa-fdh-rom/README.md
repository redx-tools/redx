# RSA Full-Domain Hash in the random oracle model

## Target security games and hardness assumptions

RSA Full-Domain Hash is a signature scheme. 
This example proves two core hops of the EUF-CMA security proof of RSA-FDH 
from the one-wayness of the RSA permutation function, following Bellare and 
Rogaway, Eurocrypt '96 ("The exact security of digital signatures - How to sign 
with RSA and Rabin"), Theorem 3.1. 
This is a random-oracle proof. 

RSA Full-Domain Hash is a signature scheme given as follows:

- Key generation returns an RSA key: a modulus `N`, a public exponent
`e`, and a secret exponent `d` with `(x^e)^d = x mod N` for every `x`. The
public key is `(N, e)`; a hash `H`, modelled as a random oracle, maps messages
onto `Z_N*`, the full domain of the RSA permutation `x -> x^e mod N`. 

- Signing algorithm (on input message `m` and secret key `d`): Output `H(m)^d mod N`. 

- Verification algorithm (on input message `m`, signature `s` and RSA public key
`(N,e)`): Check if `s^e = H(m) mod N`.

The forger sees `(N, e)`, queries the hash and signing oracles, and wins with a
pair `(m*, s*)` that verifies although `m*` was never signed.

The proof chains two preparatory steps, argued on paper, with the two hops that 
redx discharges.
- Step 0 (no loss): wlog the forger hash-queries every message it later signs or
forges on — the conversion costs only extra hash queries, which populate the
random oracle's table earlier. 
- Step 1 (the lossy step): the challenger guesses, uniformly among the fresh 
hash queries, the one whose message the forgery is on, and aborts on a wrong guess; 
the guess is independent of the forger's view. 

The following hops are then discharged by redx: 
- Hop 1 (indistinguishability) replaces every hash answer,
previously a uniform element of `Z_N*`, by `x^e mod N` for a fresh uniform `x`
— the two views are identically distributed, `x -> x^e` permuting `Z_N*`, so
per the information-theoretic-assumption idiom the distributional
equality itself is the hard problem `H_perm`: for caller-supplied
key-generation coins `r`, distinguish a uniform element of `Z_N*` from `x^e`
under the key derived from `r`. 
- Hop 2 (reachability) takes the right game of
hop 1 — every hash answer `x^e` for a known fresh `x` — with the EUF-CMA
winning condition restored, and reduces it to RSA one-wayness: given `(N, e)`
and uniform `y`, find `y^d`.

## Equational theory

Besides pairing projections, the theory carries both orientations of the RSA
permutation: `modexp(modexp(x, e(r), N(r)), d(r), N(r)) = x` and its converse.
Verification needs the `d`-then-`e` direction; hop 2's reduction signs with
the preimage `x` of its own hash answers, valid by the `e`-then-`d` direction.

## Modelling notes

- Per step 0, the games never hash internally: `gsign` and `gfin` load
  the table the forger's own queries filled.
- The random oracle appears as four oracles, the product of two
  splits. Step 1's guess splits queries by role: the `gro` family
  serves the signable queries, whose messages `gsign` may later sign,
  while `grostar` serves the target query, which `gfin`'s forgery must
  use — the game cannot branch on the guess, so the adversary routes
  each query. Each family then splits fresh versus repeated: `gronew`
  and `grostar` sample and store, `groold` and `grostarold` replay
  from the stored table.
- The `gfin` oracle in Hop 1 drops the forgery check and instead checks
  whether the adversary can distinguish between the two sides of the hop --- 
  a standard move for game hopping arguments. The `gfin` oracle of Hop 2 then
  brings it back.
- In hop 2, `ginit` needs to sample the target hash's seed into the `StarSeed`
  cell, and `grostar` serves the stored sample. The game thus creates
  the target value where the assumption delivers its challenge:
  one-wayness hands over `y` at `hinit`, together with the key. 
  In principle, our "maysample" analysis should cover `grostar`,
  morally a call-once oracle (the guess designates a single target
  query), but once-ness must be visible as a self-guarded constant
  cell, and the state discipline leaves no room for one next to
  `grostar`'s per-message rows. Sampling the seed at `ginit` instead is
  the workaround. A natural relaxation of our state discipline would let an 
  oracle carry one self-guarded constant cell besides its scope; we leave 
  its soundness analysis to future work.

## Supported backends

Hop 1: proverif only — tamarin does not support indistinguishability games.
Hop 2: proverif and tamarin.

## Results and interpretation

### Reduction

Hop 1: the reduction samples its own key-generation coins, answers both hash
oracles with `hperm` samples under them, and signs with its own `d`. 

Hop 2 is Bellare and Rogaway's reduction: forward `(N, e)`; answer `gronew` 
with `x^e` for a fresh `x` of its own and sign with that `x`; answer `grostar` 
with the challenge `y`; read `y^d` off the forgery.

### Side-conditions

None.
