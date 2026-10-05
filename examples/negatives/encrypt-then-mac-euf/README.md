# Encrypt-then-MAC against plain EUF-CMA

## Target security game and hardness assumption

The same game G as `encrypt-then-mac/hop1`, but the hard problem H is 
plain EUF-CMA: `hmac` logs only the message and `hfin` 
demands a fresh *message*, where the SUF-CMA game
of `encrypt-then-mac/hop1` demands a fresh message--tag *pair*.
Encrypt-then-MAC needs the latter: with a MAC that is EUF-CMA but
verifies more than one tag per message, an adversary can swap the tag
on an issued ciphertext into a fresh valid pair. The decryption oracle 
then accepts a ciphertext the encryption oracle never issued, although 
no message ever carried a forged tag (Bellare and Namprempre, Asiacrypt 2000). 

redx synthesises a reduction, but the side-conditions encode the precise gap 
between EUF-CMA and SUF-CMA.

## Equational theory

Same as `encrypt-then-mac/hop1`, plus `vermac(m, mac(k,m), k) = ok()`.

## Modelling notes

Same as `encrypt-then-mac/hop1`, except H's log: `Macd` is indexed by
the message alone, realising EUF-CMA.

## Supported backends

Both proverif and tamarin (a reachability game).

## Results and interpretation

### Reduction

redx synthesises the same reduction as for `encrypt-then-mac/hop1` —
the R.os files are identical for each backend.

### Side-conditions

One instance per `hmac` call — `genc`'s and `gchal`'s — each reading:

    if `(c*,t*)` verifies under `kM` and `(c*,t*) != (c, mac(kM, c))`, 
    then `c* != c`. 

where (c*,t*) represents the adversary's bad call to the decryption oracle (a 
ciphertext never issued by enc) and c:=enc(kE,rE,m) represents the encryption 
obtained during any arbitrary call to `genc` (respectively, `gchal`).

Assuming `(c*,t*)` indeed verifies under `kM` and taking the contrapositive, 
this simplifies to: `c* = c => (c*,t*) = (c, mac(kM, c))`, i.e., `t*=mac(kM,c*)`.
In other words, the condition demands that no second tag verifies for an 
already-tagged ciphertext — exactly the strong-unforgeability caveat on 
encrypt-then-MAC. A MAC with re-randomisable tags, for example, falsifies it.
