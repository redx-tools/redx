# Lamport one-time signature (arbitrary message length)

Lamport's one-time signature scheme signs an n-bit message with hash
preimages: the signing key holds two random strings per message
position, the public key holds their hashes, and a signature reveals, at
each position, the string selected by the message bit; verification
hashes the revealed strings and matches them against the public key. 
The scheme is one-time: the strings revealed by two
signatures on different messages mix and match into forgeries.

This example proves EUF-1CMA for messages of arbitrary length, 
with the one-wayness of hash as the hard problem. 
The intuition is that a forgery on a fresh message contains
a hash preimage at some position where it differs from the signed
message. The target game is the selective variant where that position
and bit are known in advance; it is obtained from EUF-1CMA by a
guessing argument argued on paper (loss 2n), and the synthesised
reduction afterwards is unconditional.

## Target security game and hardness assumption

The target is the selective game: the position and bit at which the
forgery differs from the query are known in advance. Our synthesised 
reductions are perfect --- they win H whenever the winner wins G --- whereas a
reduction from the adaptive game must guess the differing position
and bit, and succeeds only with probability 1/2n.

The game G, writing star for the known position:

- ginit publishes the public-key pair at position star.
- gpk(i) publishes the pk pair at any other position i: for star,
  this oracle is folded into the initialisation.
- gsign((i, b)) signs bit b at position i, revealing proj(b, sk_i),
  where proj picks the component of sk by the message bit: proj(zero_ud(), sk) =
  fst(sk) and proj(one_ud(), sk) = snd(sk). At most one bit is ever
  served per position, which is the one-time condition of Lamport's one-time signatures.
- gsignstar serves the query at position star, restricted to bit zero and to a
  single call.
- gfin accepts a preimage of star's bit-one hash: the forgery element
  at the position where it differs from the query.

Relative to textbook EUF-1CMA, the query arrives position by position
and the forgery is verified only at star; both changes enlarge the
class of winners, so the synthesised reduction covers the textbook
game.

The hard problem H is the one-wayness of hash: hinit publishes
hash(s) and hfin accepts any preimage.

## Modelling notes

- The list idiom (see the paper's modelling idioms): keys, messages,
  and signatures are lists, which the language cannot hold, so gpk
  and gsign expose the position as an argument and serve one element
  per call.
- gpk samples position i's pair lazily, at the first call for i;
  ginit does the same for star at initialisation, absorbing star's pk
  oracle.

## Supported backends

proverif and tamarin: the game is a reachability game and the theory
is AC-free.

## Results and interpretation

### Reduction

The reduction embeds the one-wayness challenge as star's bit-one
public-key entry: ginit calls hinit, places its output hash(s) there,
and samples the bit-zero string itself. All other positions are
self-sampled: gpk draws each position's pair at the first call and
memoises it through write-once cells, and gsign answers with proj
recipes over the memoised pair, valid for any adversary-chosen bit.
gsignstar serves the reduction's own bit-zero string. gfin forwards
the forgery element to hfin: the game demands it must hash to star's
bit-one entry, which the reduction planted as the challenge hash(s),
so a G-winner delivers a preimage.

The tamarin backend produces the identical reduction under different
generated names.

### Side-conditions

None.