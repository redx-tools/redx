# Encode-then-sign: forgery over encoded messages

The minimal example with a non-trivial side condition: synthesis
succeeds, but the reduction is sound only under a side-condition that the
pipeline emits.

## Target security game and hardness assumption

The target game G is EUF-CMA-style forgery of a scheme that signs encoded
messages: gsign returns sign(sk, f(m)) for an encoding function f (akin to 
hash-then-sign with f acting as the hash)
and gfin accepts a pair (s, m) where s is a verified signature against f(m) 
and m was never queried to gsign. The hard problem H is plain EUF-CMA of the
signature scheme. This reduction works only if f is injective.

This is the companion of [sign-then-encode](../sign-then-encode), with
f on the other side of sign: f(sign(sk, m)) there, sign(sk, f(m)) here.
There the reduction runs f's inverse on the forgery, so f must be efficiently 
invertible, and finv(f(x)) = x must be an equation of the theory. 
Here the reduction never inverts f, and the proof needs only the weaker 
property that f is injective — implied by invertibility, but satisfiable 
without any efficient inverse. That injectivity is exactly what the side 
condition below states.

## Modelling notes

- (same as sign-then-encode)

## Supported backends

proverif and tamarin.

## Results and interpretation

### Reduction

Both backends synthesise the same reduction: it applies the encoding itself, 
answering gsign(m) by hsign(f(m)) and massaging the G-forgery (s*,m*) to obtain 
the H-forgery (s*, f(m*)).

### Side-conditions

The generated condition (after unfolding the pairing terms) can be read as follows:

    (m* != m.1 && verify(s*, f(m*), pk(sk)) = ok) ->  f(m*) != f(m.1)

(sk abbreviates the output's sample_key(rsk).)

which is implied by the injectivity of f on the queried messages, the analogue
of the collision-resistance premise in the hash-then-sign theorem. If f
had collisions, a forgery on a fresh m* with f(m*) = f(m) for a signed
m would win G while R's hfin call is rejected. This obligation is left
to the user.
