# Multi-challenge IND-CPA (hybrid argument)

The hop between adjacent hybrids of the multi-challenge IND-CPA proof, stated
for an arbitrary hybrid index. This example establishes the hybrid-argument
encoding: one synthesis problem justifies the hop for every index, and the
walk across the whole family of hybrids remains on paper.

## Target security games and hardness assumptions

The target G presents a plain encryption oracle `genc` and a
challenge oracle split around the index (below); the assumption H is
single-challenge IND-CPA, an encryption oracle `henc` plus a call-once
left-or-right oracle `hlor`.

## Modelling notes

- The hybrid split of the challenge oracle: `gchal_lt` serves queries
  before the hybrid index with an encryption of the first message, `gchal_gt`
  serves queries after it with an encryption of the second, and
  `gchal_curr` serves the hybrid index itself, carrying the `diff` between the
  two encryptions.
- The index never appears as data: the adversary routes each query to
  the oracle matching the query's position, a split it can decide since
  it knows its own query count.
- `gchal_curr` is call-once via an emptiness check and store on a
  write-once cell at the constant row `constscope()`.
- The original finalisation gives way to `gfin`, which requires the
  guess to equal `diff[one, zero]`.


## Supported backends

proverif only — tamarin does not support indistinguishability games.

## Results and interpretation

### Reduction

Pure plumbing: `genc`, `gchal_lt`, and `gchal_gt` go through `henc` on the
appropriate message, `gchal_curr` through `hlor`, and the guess through
`hfin`.

### Side-conditions

None.
