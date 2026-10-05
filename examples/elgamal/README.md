# El Gamal IND-CPA, in two hops

## Target security games and hardness assumptions

hop1 and hop2 prove IND-CPA security of El Gamal encryption from DDH.
The El Gamal IND-CPA game samples a secret exponent s and an internal bit b,
publishes pk = g^s, and answers the single challenge query (m_0, m_1)
with (g^r, m_b * pk^r); the adversary wins by guessing b. 

Hop 1 replaces the pad pk^r by a random group element g^z, justified by DDH. 
Hop 2 replaces the padded message m_b * g^z by the bare pad g^z 
--- an information-theoretic step with no computational assumption behind it, 
posed as reduction to the hard problem "one-time pad in the group": 
H's hpad oracle returns diff(m * g^z, g^z) for a fresh z per call.

After hop 2, the ciphertext is the random pair (g^r, g^z), independent of b, 
which closes the proof.

## Equational theory

Besides pairing projections, E has the exponent-tower equation
expo(expo(g, x), y) = expo(g, mul(x, y)), identifying pk^r with the
Diffie-Hellman product.

## Modelling notes

- Exponents and the bit follow the sample_exp / sample_bit wrapper
  discipline.
- The challenge bit is internal: gchal selects the message by ifte over
  a stored bit, not by the diff. The diff marks the hop's two worlds:
  hop 1 pads m_b with pk^r on the left and g^z on the right; hop 2
  sends m_b * g^z on the left and the bare pad g^z on the right.

## Supported backends

ProVerif only, for both hops: they are indistinguishability games,
which the Tamarin backend does not support.

## Results and interpretation

### Reduction

The synthesised reductions are the textbook ones. 

Hop 1's reduction receives (X, Y, Z) from hinit, publishes X as the public key, 
answers the challenge with (Y, ifte(b, m1, m0) * Z) for a bit b of its own,
and forwards the guess: Z = X^y reproduces the real game, random Z
hop 1's right world. 

(Note that the game samples r and z at gchal while DDH
delivers them at hinit: the reconstruction's once analysis lets the
single hinit call, hosted at ginit, serve the single challenge through
store/load.)

Hop 2's reduction runs the game itself --- own key, own bit, own g^r --- 
and obtains the second ciphertext component from hpad(m_b).

### Side-conditions

None.
