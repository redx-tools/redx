# FOO protocol

The protocol is the FOO e-voting protocol [1] where the 
mixnet collects data of the voters Alice and Bob through a private channel.

The reduction proves the secrecy of Alice's and Bob's private channel 
modelled using encryption. 

We follow the recent Squirrel proof in [2], specialised for the bounded case of 
3 voters --- two honest voters Alice and Bob, and a single adversarially 
controlled voter Charlie. Further, we only discharge the initial two hops of the 
full proof. Each of these hops targets one of the two mixnets employed in FOO. 
This example builds on top of the abstract [mixnet](../mixnet) example, 
by using it in the context of a larger protocol.

## Target game and hardness assumption

The modelled game has the following oracles, besides init and fin:
    - All Alice and Bob's oracles `Alice*` and `Bob*`: for Alice/Bob's 
    authentication through blind signautres, or to send their commitments or 
    commitment keys to one mixnet.
    - `MixnetCollect1Alice`/`MixnetCollect1Bob`: the first mixnet collects 
    Alice/Bob's encrypted commitments and stores their underlying plaintext 
    vote internally.
    - `MixnetCollect2Alice`/`MixnetCollect2Bob`: the second mixnet collects 
    Alice/Bob's encrypted commitments and stores their underlying plaintext 
    internally.
    - `MixnetCollect1Charlie` and `MixnetCollect2Charlie`: the mixnets collect 
    the adversary's encrypted vote and stores its decrytion internally.
    - `MixnetPublish[1/2]`: the mixnet publishes a shuffle of the decrypted 
    votes.

The hardness assumption in both hops is the IND-CCA2 assumption.

## Modelling notes

Just like in the mixnet example, an over-approximation appears when modelling 
the hardness assumption and we get around this limitation by providing the 
same user-supplied axiom as in the mixnet example (in axioms.pv).

## Equational theory

Besides pairing projections, the expected correctness of encryption and 
decryption scheme.

## Supported backends

ProVerif only: they are indistinguishability games, which the Tamarin 
backend does not support.

## Results and interpretation

### Reduction 

Alice and Bob's messages are computed using the encryption oracle, replacing 
the encryption of their secret messages by encryption of dummy messages.

The mixnet's decryption is made using the decryption oracle. Collecting Alice 
and Bob's encryption is made in separated oracle to prevent from decrypting 
Alice and Bob's encrypted messages.

### Side-conditions

None.


[1] Atsushi Fujioka, Tatsuaki Okamoto, and Kazuo Ohta.
A practical secret voting scheme for large scale elec-
tions. In AUSCRYPT, volume 718 of Lecture Notes in
Computer Science, pages 244–251. Springer, 1992.

[2] David Baelde, Adrien Koutsos, Justine Sauvage.
Leveraging cryptographic simulator synthesis for formally verifying the 
FOO e-voting protocol. In Usenix Security Symposium 2026. 