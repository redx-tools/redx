# Signature domain extension without tags

## Target security game and hardness assumption

Domain extension for signatures: building a scheme for longer
messages from a scheme for shorter ones. The textbook route (Katz and
Lindell, Introduction to Modern Cryptography, 2nd ed., Exercise 12.1)
splits the message into blocks and signs each block together with
bookkeeping data --- a fresh message identifier, the message length,
the block index --- and dropping any of these admits a textbook
forgery. This textbook construction is considered in the companion 
example [sig-domain-extension](../../sig-domain-extension).

This example models a chained variant with all bookkeeping 
dropped: signing the triple (m1,m2,m3) returns (s1,s2) with

    s1 = sign(sk, (m1,m2))
    s2 = sign(sk, (m3,s1)),

the chain binding the third block to the first two through s1. The
target game G is EUF-CMA of the extended scheme --- gtriplesign signs
adversary-chosen triples, gfin accepts a valid signature on a fresh triple ---
and the hard problem H is EUF-CMA of the base scheme.

The construction is insecure by mix-and-match across two queries:

    q1 = (a,b,c)      gives  s1 = sign(sk,(a,b)),  s2 = sign(sk,(c,s1))
    q2 = (d,s1,e)     gives  t1 = sign(sk,(d,s1))

and (a,b,d) with signature (s1,t1) is a valid forgery: s1 verifies
the first block (a,b), t1 verifies the chained block (d,s1), and the
triple (a,b,d) was never queried. 

redx synthesises a reduction but carries a side-condition that encodes such 
mix-and-match.

## Equational theory

Pairing projections only: fst(pair(x,y)) = x and snd(pair(x,y)) = y.

## Modelling notes

- Triples (a,b,c) are represented as pair(pair(a,b),c)

## Supported backends

Both proverif and tamarin (a reachability game).

## Results and interpretation

### Reduction

The proverif reduction answers gtriplesign by two hsign calls, one
per step. At gfin, it obtains a forgery ((m1',m2',m3'),(s1',s2')) and 
submits (m3',s1') with signature s2' to hfin as its own forgery. 
It wins H only if hsign never signed the pair (m3',s1'), which
G's win does not guarantee.

The tamarin backend synthesises the mirror reduction, forwarding 
((m1',m2'), s1') to hfin.

### Side-conditions

Focusing on Proverif's output first. To win H, the message (m3',s1') submitted
by the reduction to hfin must not clash with any previous queries to hsign.
Writing (m1,m2,m3) for a gtriplesign query and s1 for its first-step
signature, condition 1 prevents a clash with the query's first-step message
and condition 2 with its second-step message:

    forged triple fresh and both steps verify
        implies  (m3',s1') != (m1,m2)    (condition 1)
        implies  (m3',s1') != (m3,s1)    (condition 2)

The mix-and-match winner falsifies condition 1: in the attack above, the
forgery's chained message (d,s1) is exactly the first block of the
query (d,s1,e). The falsified condition thus describes the attack.

Condition 2 is benign. Suppose it
fails, so m3' = m3 and s1' = s1. 
The forgery also needs s1' to verify against its own first
block (m1',m2'). Now (m1',m2') cannot coincide with (m1,m2): the
forged triple would be the already queried (m1,m2,m3), and the
condition's premise requires it to be fresh. So (m1',m2') differs
from (m1,m2), and verification accepts the single signature s1 for
two different messages. The condition actually holds under any EUF-CMA
base scheme: a violating winner's ((m1',m2'), s1) is itself 
a base-scheme forgery, just not the one our reduction forwards.
A classical proof would branch here --- whichever of the two pairs is fresh, 
forward that one --- but our reductions are straight-line code and cannot branch, 
so the missing arm surfaces as this side-condition. Assuming it costs
nothing.

The tamarin backend's two conditions mirror these, with the forged
first block (m1',m2') in place of (m3',s1'):

    forged triple fresh and both links verify
        implies  (m1',m2') != (m1,m2)    (condition 1)
        implies  (m1',m2') != (m3,s1)    (condition 2)

The mix-and-match winner above falsifies condition 1: the forgery's
first block (a,b) is the first block of the query (a,b,c). Condition 2,
unlike its proverif counterpart, is falsified by a second mix-and-match
attack, where the role confusion runs in the other direction --- a first-step
signature certifies a chained pair:

    q1 = (a,b,c)      gives  s1 = sign(sk,(a,b)),  s2 = sign(sk,(c,s1))
    q2 = (d,s2,e)     gives  t1 = sign(sk,(d,s2))

and (c,s1,d) with signature (s2,t1) is a valid forgery: s2 verifies
the first block (c,s1), t1 verifies the chained block (d,s2), and the
triple (c,s1,d) was never queried. Its first block is q1's chained
message (c,s1), falsifying condition 2.
