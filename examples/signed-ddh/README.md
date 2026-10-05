# Signed Diffie–Hellman

## Target security games and hardness assumptions

`hop1/` and `hop2/` prove real-or-random secrecy of the initiator's derived
key in the signed DH protocol 
`A -> B: (pk(skA), g^a)`;
`B -> A: (pk(skB), g^b), sign(skB, ((g^a, g^b), pkA))`;
`A -> B:sign(skA, ((g^b, g^a), pkB))`. 

### Hop 1 (signature unforgeability) 

Hop 1 shows that if Alice's verification return ok() and sends back her signature, 
then Alice's received a signature of the form <_, g^b>,_.


### Hop 2 (indistinguishability)

After Hop 1, the oracle `AliceSnd` is guarded on the share being exactly `g^b`.
Then, Alice's output key is exactly `g^ab` if the real protocol, and `g^k` on the random size, for a fresh exponent `k`? The hop is a redution to DDH in textbook form: `hinit` delivers the whole tuple `(g^x, g^y, diff(g^xy, g^z))`.

## Equational theory

Exponent collection `expo(expo(g, x), y) = expo(g, mul(x, y))` and canonical
signature verification `verify(m, sign(k, m), pk(k)) = ok()`. Hop 1
additionally folds Alice's verification guards into her response through
`ifteq`, with `ifteq(x, x, f) = f`; hop 2 uses plain `chk` guards instead.

## Modelling notes

- Hop 2 samples all of G's challenge randomness eagerly at `ginit`, per
  the eager-sampling convention, so that H's init-time names home there.
- Exponents are drawn through `sample_exp` wrappers, keeping sampled
  exponents syntactically distinct from derived ones.
- A write-once cell orders `AliceFst` before `AliceSnd`.
- Hop 2 bakes hop 1's guarantee in as a guard
  (`chk snd(fst(y)) = expo(g(), b)`).

## Supported backends

Hop 1: proverif and tamarin.
Hop 2: proverif only — tamarin does not support indistinguishability games.

## Results and interpretation

### Reduction

Hop 1: the reduction plants H's public key as Bob's, obtains Bob's one
signature from `hsign`, and forwards Alice's accepted transcript, reassembled
into the signed message, to `hfin`. 

Hop 2: it plants `g^y` as Alice's share
and `g^x` as Bob's, signs with keys of its own, and outputs the third tuple
element as the key.

### Side-conditions

Hop 1 (identical for both backends): the message Alice accepted must differ
from the message Bob signed — `hfin` pays only for unsigned messages. Not a
syntactic tautology, but it holds in every model of the equations: the
projection equations make pairing injective, so equal messages would force
`snd(fst(yB)) = g^b` in the second slot, and the premise gives
`snd(fst(yB)) != g^b`. 

Hop 2: none (`sc.th` is empty).
