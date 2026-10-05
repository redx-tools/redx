# Signature unblinding (XOR): EUF-CMA from a whitened signing oracle

The same game as
[signature-unblinding-mul](../signature-unblinding-mul) over the XOR
theory, which adds nilpotence (xor_ud(x, x) = zero_ud()) and a unit on
top of AC — the tamarin-unchained backend handles this richer
algebraic structure too. The theory coincides, equation for equation,
with Tamarin's builtin xor, which allows a cross-check of the
attack-finding step against stock Tamarin (below).


## Target security game and hardness assumption

The target game G is plain EUF-CMA of a signature scheme. The hard
problem H is EUF-CMA of a masked scheme sign'(sk, m) =
sign(sk, xor_ud(m, d)), where xor_ud denotes a user-defined XOR operation and 
d is a public offset output at init. The
reduction must remove the offset: to have H sign m it queries
hsign(xor_ud(m, d)), and the simulation is correct only because
xor_ud(xor_ud(m, d), d) = m.

## Equational theory

Pairing projections plus the XOR equations used for the builtin xor operator in 
Tamarin. Note that although Tamarin supports XOR, we use here a user-defined 
symbol xor_ud instead of Tamarin's builtin xor and copy all the equations used 
by Tamarin's builtin XOR theory. This is because redx currently handles every 
theory through one uniform path where all equations are explicitly loaded from 
eq.th and no built-in theories are loaded from the backend. 

ac.txt declares xor_ud as associative-commutative. 

## Modelling notes

- Standard store/empty bookkeeping: the signing oracles store each signed 
  message, and fin requires the forged message's cell to be empty.

## Supported backends

tamarin-unchained only: the theory has a user-declared AC symbol, which neither 
proverif nor stock tamarin accepts.

## Results and interpretation

### Reduction

To simulate gsign(m), the reduction 
calls hsign(xor_ud(m, d)), so H signs xor_ud(xor_ud(m, d), d) = m
modulo the theory. The forgery is submitted with its message
XOR-offset by d likewise.

### Side-conditions

The condition says (after unfolding the pairings) that 
freshness must survive the whitening:

    m* != m.1 && verify(s*, m*, pk(sk)) = ok
      ->  xor_ud(m*, ~d_2) != xor_ud(m.1, ~d_2)

(sk abbreviates the output's sample_key(rsk).)

Not a syntactic tautology, but XORing d back recovers the message
(xor_ud(d, xor_ud(d, x)) = x modulo AC), so equal masked messages
force m* = m.1, contradicting the premise. The condition holds in every
model of the equations.

### Stock-Tamarin cross-check

As a sanity check, we also verify that stock tamarin finds the same attack. 
[to-builtin-xor.sh](to-builtin-xor.sh) translates the generated model
mechanically to stock Tamarin's builtin xor: it adds `builtins: xor`,
drops the xor_ud/zero_ud declarations and their equations, and rewrites
xor_ud(a, b) to (a XOR b).

    ./redx tamarin-unchained toys/signature-unblinding-xor
    cd examples/toys/signature-unblinding-xor
    ./to-builtin-xor.sh > builtin-xor-model.spthy
    ../../../vendors/tamarin-prover/out/tamarin-prover --prove \
        --derivcheck-timeout=0 builtin-xor-model.spthy

Stock Tamarin falsifies SecurityProperty — the same 13-step attack —
in about 7 s, against 138.8 s for Tamarin-Unchained's generic AC treatment.
