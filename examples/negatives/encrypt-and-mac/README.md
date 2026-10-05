# Encrypt-and-MAC

## Target security game and hardness assumption

The Encrypt-and-MAC composition: encrypting m returns
pair(enc(kE, rE, m), mac(kM, m)), the tag computed over the message
rather than the ciphertext. The target game G is the IND-CPA game of the
composite scheme and the hard problem H is IND-CPA of enc alone. 

The scheme is insecure: the tag is a deterministic function of the
plaintext, so it leaks plaintext equality.

## Supported backends

proverif only: the tamarin backend does not support indistinguishability games.

## Results and interpretation

### Reduction

None: sample-proverif-R.os is the "null" marker.

### Side-conditions

None; with no reduction, no side-conditions are generated.
