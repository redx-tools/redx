# Basic Hash (authentication)

## Target security game and hardness assumption

The target game G is the Basic Hash protocol (see
[the protocol README](../README.md)) with an authentication win: the
adversary wins (gfin) if the reader accepts a pair whose nonce no tag
session produced. The hard problem H is EUF-CMA of the MAC, with hash
as the MAC and the equation verify(m, hash(k, m), k) = ok().

## Modelling notes

- Each gtag call stores a dummy constant ok() at Tagged[n]: the
  write-once table serves only to log whether a given nonce n was
  previously tagged or not.
- gfin's emptiness check at fst(tagstar) says the accepted nonce is
  not in the log.

## Supported backends

proverif and tamarin: the game is a reachability game and the theory
is AC-free.

## Results and interpretation

### Reduction

The reduction wires G to H one-to-one: hinit for ginit, one hhash
query per gtag (the reduction samples the nonce itself), hver for
gread, and the accepted pair as the forgery at hfin.

Note that in this case, the state of G is completely simulated by H, and 
the reduction itself is stateless with no store/load.

### Side-conditions

The one side condition is a tautology --- its conclusion,
fst(tagstar) != n.1, is among its premises --- because the reduction
hashes exactly the nonces the tag logs, so G's freshness guard over
Tagged coincides with H's freshness guard over Hashed.
