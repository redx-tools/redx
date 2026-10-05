# Signature domain extension

## Target security game and hardness assumption

Domain extension for signatures: building a scheme for longer
messages from a scheme for shorter ones. The construction is Katz and
Lindell's (Introduction to Modern Cryptography, 2nd ed., Exercise
12.1): to sign a message of blocks m1,...,md, draw a fresh identifier
rid and sign, for each block, the message rid || ell || i || mi,
where ell is the message length and i the block's position. Each
piece of bookkeeping stops one attack: the identifier stops mixing
blocks of two signed messages, the position stops reordering blocks
within one, and the length stops truncation. Instantiated here for
triples, signing ((m1,m2),m3) draws rid and returns

    sig = (rid, s1, s2, s3),    si = sign(sk, pair(rid, pair(ell, pair(idxi, mi))))

The target game G is EUF-CMA of the extended scheme --- gtriplesign
signs chosen triples, gfin accepts a valid signature on a fresh
triple --- and the hard problem H is EUF-CMA of the base scheme.

The bookkeeping is exactly what the insecure companion
[sig-domain-extension-untagged](../negatives/sig-domain-extension-untagged)
drops: there a mix-and-match forgery assembles a fresh triple out of
stale blocks; here the identifier and the index pin every block to
one query and one position.

## Equational theory

Pairing projections only: fst(pair(x,y)) = x and snd(pair(x,y)) = y.

## Modelling notes

- Freshness of the forged triple is bookkept with a store/empty pair:
  gtriplesign stores each queried triple in Signed and gfin requires
  the forgery's cell to be empty.
- Triples have fixed arity, so the length is the constant ell ---
  kept for fidelity to the construction --- and the textbook
  verifier's block-count check (d' = d) is structural.

## Supported backends

proverif only. The tamarin backend accepts the model but its search
went out of memory (killed at an 8 GB limit within three minutes): the
compiled hsign wraps each call in a lock (one token for the whole oracle), 
and tamarin's lock restriction case-splits on the temporal ordering of every 
pair of lock sessions --- with three hsign sessions per gtriplesign query
instead of two, the pair count and thus the search tree blows up. 

## Results and interpretation

### Reduction

redx synthesises the textbook reduction: it draws the identifier
itself and answers gtriplesign by three hsign calls, one per bookkept
block; at gfin it forwards one block of the forgery --- message and
signature --- as its H-forgery (the synthesised reduction picks the
second block).

### Side-conditions

To win H, the reduction must hand hfin a message that hsign never
signed. But the reduction itself calls hsign three times per
gtriplesign query, once per block. That gives three conditions, one
per call: even when the adversary wins G, the block the reduction
forwards must differ from the first, the second, and the third
message signed for a query.

Two of the three hold directly: the forwarded message contains
idxtwo, while the first and third signed messages contain idxone and
idxthree. The index constants differ, so the messages cannot be
equal.

The condition against the second signed message is substantive. 
With the nested pairs flattened, it reads

    forged triple fresh and all three blocks verify
        implies  (rid', ell, idxtwo, m2') != (rid_q, ell, idxtwo, m2_q)

where rid' and m2' come from the forgery, and rid_q and m2_q from a
query q. In words: the forgery must not reuse a query's identifier
together with that query's middle block.

No winning adversary can do this: a violation forces either a valid
signature on a message hsign never signed --- a forgery against the
base scheme --- or two queries sharing an identifier, and the
hardness assumption excludes the first, the freshness of rid the
second. This argument is precisely the security proof of the
construction (Katz--Lindell, Theorem 4.8), living where side
conditions live --- outside the symbolic search.