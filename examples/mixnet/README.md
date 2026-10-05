# Mixnet protocol

The protocol is a portion of the FOO e-voting protocol [1] where the 
mixnet collects data of the voters Alice and Bob through a private channel.

The reduction proves the secrecy of Alice's and Bob's private channel 
modelled using encryption. 

This example models the abstract mixnet proof showcased as the motivational 
example in [2].

## Target game and hardness assumption

The modelled game has the following oracles, besides init and fin:
    - `Alice`/`Bob`: Alice/Bob cast their vote or dummy.
    - `MixnetCollectAlice`/`MixnetCollectBob`: the mixnet collects Alice/Bob's
      encrypted votes and stores their underlying plaintext vote internally.
    - `MixnetCollect`: the mixnet collects the adversary's encrypted vote and 
      stores its decrytion internally.
    - `MixnetPublish`: the mixnet publishes a shuffle of the decrypted votes.

The hardness assumption is the IND-CCA2 assumption.

## Modelling notes

The vanilla run against Proverif fails to find a reduction and our modelling 
for this example tries to work around this limitation. 
Due to Proverif's over-approximation, it proposes an attack that it cannot 
concretise into a real attack. This is normal Proverif behavior, but unlike 
reachability queries where Proverif then attempts to retry with a 
different proposal (till the number of retries governed by the 
`reconstructTrace` option), in diff-mode it gives up after failing to 
concretise the first proposed attack.

The over-approximation appears when modelling the hardness assumption - the  
IND-CCA game. Here, the decryption oracle is required to check if the 
input ciphertext was already queried to the challenge oracle; if not, 
then it proceeds to respond, and if yes, then it aborts. However, because 
Proverif cannot reason about negative facts, it admits an attack that 
supplies the challenge ciphertext to the decryption oracle, taking the 
no-branch and giving the attacker the decryption of the challenge ciphertext!
The proposed attack is later rejected during the concretisation step, but then 
Proverif stops, never reaching the actual attack that encodes the 
genuine reduction.

We get around this limitation by providing a user-supplied axiom (in axioms.pv) 
that forbids both "store" and "emptychecked" events on the 
same object in the trace. redx forwards this and embeds it as a standard 
Proverif axiom.

This is a real workaround and points to a real tool limitation, 
since the axiom is not general. In general, a trace can have store and 
emptychecked events on the same object, if the emptychecked event occurs 
before the store. But one cannot express such temporal axioms in Proverif.

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