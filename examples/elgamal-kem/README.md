# El Gamal KEM IND-CPA, in two hops

## Target security games and hardness assumptions

hop1 and hop2 prove IND-CPA security of the El Gamal (hashed
Diffie-Hellman) KEM from DDH and entropy smoothing of the underlying hash Ha.
The KEM IND-CPA game has no challenge oracle (cf. ePrint 2020/1364):
the adversary receives its whole input (pk, c, k) = (g^s, g^r, key)
at ginit and must tell whether k is the encapsulated key Ha(pk^r) or
uniform. 

Hop 1 replaces Ha(pk^r) by the hash of a random group element Ha(g^z), 
justified by DDH. 

Hop 2 replaces Ha(g^z) by a uniform key, justified by an entropy smoothing 
assumption on Ha. This hardness assumption H delivers diff(Ha(g^z), k) for 
fresh z and k at hinit. 

The right world of hop 2 is the ideal KEM game, which closes the proof.

The companion example [elgamal-kem-rom](../elgamal-kem-rom) proves the
same scheme in the random oracle model, where the proof becomes an
upto-bad argument discharged via CDH.

## Equational theory

The exponent-tower equation expo(expo(g, x), y) = expo(g, mul(x, y))
identifies the encapsulated key's argument pk^r with the
Diffie-Hellman product; the rest is pairing projections.

## Modelling notes

- Both games are stateless --- one output at ginit, then the guess at
  gfin.
- Sampling follows the sample_D discipline: exponents via sample_exp,
  keys via sample_key, and random group elements as g^sample_exp(seed).

## Supported backends

ProVerif only, for both hops: they are indistinguishability games,
which the Tamarin backend does not support.

## Results and interpretation

### Reduction

Hop 1's reduction forwards the DDH tuple: X becomes the public key, Y
the encapsulation, and the key is Ha(Z). Z = X^y gives the real
world, random Z gives the hashed-random world. 

Hop 2's reduction samples its own s and r and forwards H's challenge 
verbatim as the key.

### Side-conditions

None.
