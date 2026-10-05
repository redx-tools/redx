# Encrypt-then-encode: indistinguishability of encoded ciphertexts

The minimal indistinguishability example, establishing the diff-mode
side of the pipeline.

## Target security game and hardness assumption

The target game G is left-right IND-CPA of a scheme that encodes its
ciphertexts: genc returns f(enc(x_b, k, r)) for an encoding function f. The
hard problem H is IND-CPA of the underlying symmetric scheme. This is
the indistinguishability counterpart of
[sign-then-encode](../sign-then-encode)'s f(sign(sk, m)), but here f
needs no inverse: winning means guessing a bit rather than exhibiting a
preimage, so the reduction only applies f to henc's answers and never
undoes it.

## Modelling notes

- The native encoding of an indistinguishability hop: the two games of
  G (and of H) are written as one diff-marked oracle system, and the
  finalisation oracle checks guess = diff(one(), zero()).

## Supported backends

proverif only: tamarin does not support indistinguishability games.


## Results and interpretation

### Reduction

The reduction forwards the challenge pair to
henc and encodes the answer with f; gfin forwards the guess. The
forwarded argument appears as pair(fst(x0x1), snd(x0x1)) rather than
x0x1 itself — a reconstruction artefact that is projection-equal once
henc takes fst and snd, so the simulation is perfect.

### Side-conditions

None.
