# DL-to-CDH

The paper's first motivational example (Section 3.1). The reduction is
found by including only the single exponentiation equation
expo(expo(g(), x), y) = expo(g(), mul(x, y)) in E, rather than the
full exponent theory, whose commutative multiplication is out of
ProVerif's reach.

## Target security game and hardness assumption

The target game G is the discrete-logarithm problem: ginit publishes
expo(g(), x) for a secret exponent x and gfin accepts x itself. The
hard problem H is CDH: hinit publishes the pair (g^a, g^b) and hfin
accepts g^(ab).

## Equational theory

Pairing projections plus expo(expo(g(), x), y) = expo(g(), mul(x, y)),
through which the reduction assembles the CDH answer from the returned
logarithm.

## Modelling notes

- Exponents are drawn through the sample_exp wrapper.

## Supported backends

proverif and tamarin.

proverif solves it in under a second. However, the default tamarin run 
takes ~45 s for a backend-internal reason — the exponentiation equation induces
deconstruction chains that Tamarin's source precomputation cannot close
(88 partial deconstructions remain), and resolving them dominates the
run. Capping that budget recovers the identical attack trace in ~7 s:

    ./redx tamarin dl-cdh --open-chains=2 --saturation=2

The cap bounds precomputation work only — any trace found is real;
a too-low cap can miss attacks, never produce unsound ones.

## Results and interpretation

### Reduction

The reduction embeds half of the CDH instance as the DL challenge:
ginit obtains (g^a, g^b) from hinit, outputs g^b to the DL solver; when the 
DL solver returns with xdash = b, gfin raises the first component of hinit's 
output — g^a — to xdash, producing g^(ab) for hfin. 
Because hinit's output is needed again at finalisation,
reconstruction memoises it through R's own write-once cell L_v0 (the
store/load pair in the output).

### Side-conditions

None.
