# Signature unblinding (mul): EUF-CMA from a blinded signing oracle

The main example of a reduction that exists only modulo an
associative-commutative symbol. Neither proverif nor
stock tamarin accepts the theory (the former having no AC support; the latter 
supporting only built-in AC theories). The reduction is found instead by the tamarin-unchained backend. As the backends grow stronger, reduction synthesis 
inherits the gain.

[signature-unblinding-xor](../signature-unblinding-xor) plays the same
game over the XOR theory, which adds nilpotence and a unit on top of
AC.

## Target security game and hardness assumption

The target game G is plain EUF-CMA of a signature scheme. The hard problem H is 
EUF-CMA of a masked scheme sign'(sk, m) = sign(sk, mul_ud(d, m)), where d is a 
constant masking factor sampled at init and published alongside the public key. 
d is public by design: the reduction must compute div_ud(m, d) to have H sign 
m. With d public, H differs from plain EUF-CMA only by the bijection taking 
each message m to mul_ud(d, m). Even this near-trivial equivalence is 
discoverable only modulo AC.

## Equational theory

Pairing projections plus the cancellation mul_ud(div_ud(x, y), y) = x;
ac.txt declares mul_ud associative-commutative. H blinds on the left
while the cancellation removes a right factor, so
mul_ud(d, div_ud(m, d)) rewrites to m only after commuting the
arguments — the reduction exists only modulo AC.

## Modelling notes

- Standard store/empty bookkeeping: the signing oracles store each signed 
  message, and fin requires the forged message's cell to be empty.

## Supported backends

tamarin-unchained only: the theory has a user-declared AC symbol, which
neither proverif nor stock tamarin accepts.

## Results and interpretation

### Reduction

The reduction divides before querying:
gsign(m) calls hsign(div_ud(m, d)), so H signs mul_ud(d, div_ud(m, d)),
which is m modulo AC and cancellation. The forgery is submitted with
its message divided by d likewise.

### Side-conditions

The condition says freshness must survive the division (sk and d
abbreviate the sampled values, which the output spells
sample_key(rsk) and sample_grp(~rd_2)):

    m* != m.1 && verify(s*, m*, pk(sk)) = ok
      ->  div_ud(m*, d) != div_ud(m.1, d)

Not a syntactic tautology, but is entailed by the theory: from
div_ud(m*, d) = div_ud(m.1, d), right-multiplying by d
gives mul_ud(div_ud(m*, d), d) = mul_ud(div_ud(m.1, d), d),
which gives m* = m.1 under the given equational theory, contradicting the 
premise. The condition thus holds in every model of the equational theory.