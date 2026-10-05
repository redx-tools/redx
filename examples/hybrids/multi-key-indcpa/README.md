# Multi-key IND-CPA (hybrid argument over keys)

The hop between adjacent hybrids of the multi-key IND-CPA proof, stated for
an arbitrary key index — the sibling of `multi-chal-indcpa`, which hybridises
over challenges under a single key; here the hybrid walks over keys, with
one left-or-right challenge per key.

## Target security games and hardness assumptions

The target game G is stated in the public-key setting: key generation is 
split around the index (below), and
each generated key admits one challenge. The assumption H is single-key
IND-CPA, `hinit` handing the challenge pk to the adversary plus a call-once
left-or-right oracle `hlor`; no encryption oracle is needed since
encryption is public.

Note that the split around kgen is necessary because in our language, the 
reduction cannot branch, yet it needs to use H for embedding the challenge key
while simulating the rest itself. The cases thus have to be pre-split.

## Modelling notes

- The hybrid split of key generation: `gkgen_lt` creates keys before the
  index, whose challenges encrypt the first message; `gkgen_gt` creates
  keys after it, whose challenges encrypt the second; `gkgen_curr` creates
  the current key itself, whose challenge carries the `diff` between the
  two encryptions.
- `gkgen_curr` samples the current key, declared call-once via an emptiness 
  check and store on a constant scope; `gchal_curr` loads the pk from there.
- The index never appears as data: the adversary routes each query to the
  oracle matching the key's position, a split it can decide since it
  knows its own query count.
- The original finalisation gives way to `gfin`, which requires the guess
  to equal `diff[one, zero]`.

## Supported backends

proverif only — tamarin does not support indistinguishability games.

## Results and interpretation

### Reduction

The textbook one: for lt/gt keys the reduction samples its own seeds, 
stores them in a pk-indexed table, and encrypts locally with the
public `enc`; the current key is `hinit`'s pk, obtained inside
`gkgen_curr`, and the current challenge goes through `hlor`, the guess
through `hfin`.

### Side-conditions

None.
