# Encrypt-then-MAC

## Target security games and hardness assumptions

`hop1/` and `hop2/` prove IND-CCA security of the encrypt-then-MAC scheme. 
Hop 1 (the paper's motivational example in Section 3.2) reduces the bad event 
that the decryption oracle accepts a pair the game never produced to the 
SUF-CMA security of the MAC (the plain-EUF-CMA variant, which does not yield 
an unconditional reduction, is in `negatives/encrypt-then-mac-euf`). Hop 2
(indistinguishability) plays the remaining game, where decryption answers only
replayed encryptions, against IND-CPA of the encryption.

## Equational theory

Both hops need only the pairing projection equations.

## Modelling notes

- Hop 1's `hmac` logs the message--tag pair (`store Macd[pair(m, t)]`) and
  `hfin` demands the pair be unlogged, realising SUF-CMA: a forgery is a
  fresh pair, not necessarily a fresh message.
- Hop 1 uses the up-to-bad oracle split. `gdec` replays the plaintext
  stored at encryption time, under an extra
  guard: its input must be a `genc` output (the load on `Encrypted`).
  `gfin` replaces the finalisation oracle and is the first bad call: a
  pair that verifies, was not the challenge, and was never output by
  `genc`.
- Hop 1 is a reachability game, so its challenge bit stays internal:
  `gchal` selects the message by `ifte` over a stored bit.
- Hop 2 keeps the split `gdec`, restores the bit-guessing finalisation,
  and carries the challenge as a `diff` over the two challenge messages.
  This is as-per our upto-bad idiom.

## Supported backends

Hop 1: proverif and tamarin. 

Hop 2: proverif only — tamarin does not support
indistinguishability games.

## Results and interpretation

### Reduction

Hop 1: the reduction keeps the encryption key and the bit to itself, tags with
`hmac`, answers `gdec` from the plaintext it memoises at encryption time, and
forwards the bad pair to `hfin`. 

Hop 2: it samples the MAC key itself, answers `genc` through `henc(pair(m, m))` 
— the left-or-right oracle doubling as the plain encryption oracle — and 
answers `gdec` without any decryption key by memoising each plaintext at 
encryption time under its ciphertext pair (a store/load pair).

### Side-conditions

Hop 1: vacuous. There is one condition per `hmac` call the reduction makes
(`genc`'s and `gchal`'s). Writing `ct = pair(c, mac(kM, c))` for the pair
that call logs, each condition has the form

```
if   ctstar != ct                                 (G's guard: the bad pair is not that output)
and  vermac(fst(ctstar), snd(ctstar), kM) = ok    (G's guard: it verifies)
then pair(fst(ctstar), snd(ctstar)) != ct         (H's demand: the forwarded pair is unlogged)
```

Re-pairing the projections gives back `ctstar`, so the conclusion is the
first premise: the condition holds for any implementation. It is printed
only because the symbolic theory lacks surjective pairing and cannot fold
`pair(fst(ctstar), snd(ctstar))` back into `ctstar` (tamarin, whose pairs
pattern-match, repeats the premise literally). The substantive condition of
the plain-EUF-CMA variant lives in `negatives/encrypt-then-mac-euf`.

Hop 2: none (`sample-proverif-sc.th` is empty).
