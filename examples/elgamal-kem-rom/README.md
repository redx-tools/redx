# El Gamal KEM in the ROM: the challenge query yields a CDH solver

This example proves the IND-CPA security of El Gamal KEM in the random 
oracle model (ROM). 

The companion example [elgamal-kem](../elgamal-kem) discusses the El Gamal KEM
scheme and argues for its IND-CPA security under the standard model. 
In that case, the proof reduces to the hardness of DDH and an entropy smoothing 
assumption about the underlying hash function. 

In this example, the hash function is modelled as a random oracle. The proof is 
an upto-bad argument discharged via the CDH assumption.

## Target security game and hardness assumption

In the random-oracle proof of the El Gamal KEM, the ideal world hands
the adversary (pk, c, k) = (g^x, g^y, uniform key) instead of the
real key RO(g^xy); the two views are identical until the adversary
queries the random oracle at g^xy. This example discharges that bad
event against CDH: reaching it yields a CDH solver. The
identical-until-bad step around it stays on paper.

The target game G models the adversary reaching the bad event (making a fresh 
RO query at exactly the Diffie-Hellman value g^{xy}), whereas the hard problem 
H is plain CDH.

## Equational theory

The exponent-tower equation expo(expo(g, x), y) = expo(g, mul(x, y)); 
the rest is pairing projections.

## Modelling notes

- The hash function is modelled as a random oracle available to the adversary, 
  which is split into two oracles as per our modeling idioms since it 
  behaves differently on fresh and old queries: 
  gronew answers a fresh query with a fresh key and
  records it under RO[q], groold replays a recorded answer.
  This step is justified because the adversary knows which of its queries are 
  fresh, hence which variant to call.
- Following the up-to-bad idiom, the bad event replaces the
  finalisation oracle: gfin carries the fresh-query guard of gronew
  plus the check qstar = g^xy, so reaching gfin is exactly the first
  bad query.
- Randomness follows the sample_exp / sample_key wrapper discipline.

## Supported backends

ProVerif and Tamarin: the game is a reachability problem, so unlike
the other El Gamal examples it is within Tamarin's remit.

## Results and interpretation

### Reduction

The synthesised reduction forwards the CDH pair (g^x, g^y) as (pk, c), 
samples the challenge key itself, and simulates the RO table with its 
own write-once cells: gronew stores a fresh seed under the query and answers
sample_key(seed); groold loads the seed and re-derives the same
answer. The winning query qstar goes to hfin verbatim as the CDH
solution.

### Side-conditions

None.
