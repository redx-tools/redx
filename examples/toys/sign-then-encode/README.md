# Sign-then-encode: forgery of encoded signatures

The minimal reachability example: it establishes the base pipeline end
to end, on a reduction that must compute with the equational theory
rather than merely forward oracle calls.

## Target security game and hardness assumption

The target game G is EUF-CMA-style forgery of a scheme that encodes its
signatures: gsign returns f(sign(sk, m)) for an invertible encoding function f,
and gfin accepts a pair (fs, m) where f^{-1}(fs) verifies as a signature on m
and m was never queried to gsign. This game's security reduces to plain
EUF-CMA security of the underlying signature scheme (H) because f is
efficiently invertible: the reduction runs the inversion algorithm
on the forgery.
Invertibility is essential: the game only asks the adversary to produce
the f-image of a valid signature, never the signature itself, and an
image can be easy to produce even when its preimage is hard.

The companion example [encode-then-sign](../encode-then-sign) signs
encoded messages instead — sign(sk, f(m)) — and demands strictly less
of f: only injectivity, with no efficient inverse. The reduction there
never inverts f, so it surfaces as a side condition rather than as an 
equation of the theory.

## Equational theory

Pairing projections plus finv(f(x)) = x, which lets the reduction undo
the encoding on the forgery.

## Modelling notes

- The requirement that the forged message should not have been signed is enforced 
  with a store/empty pair: gsign stores each queried message in GSign and 
  gfin requires the forgery's cell to be empty.

## Supported backends

proverif and tamarin.

## Results and interpretation

### Reduction

Both backends synthesise the same reduction: forward the public key, answer 
gsign by encoding hsign's answer with f, and undo the encoding on the forgery 
with finv before passing it to hfin.

### Side-conditions

The generated side-condition is a tautology: the conclusion is the first 
conjunct of the premise.
