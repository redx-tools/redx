# Homomorphic tally

Tally integrity of a Helios-style homomorphic tally, reduced to
the EUF-CMA security of the registrar's signature scheme. 
This example mainly demonstrates the use of user-defined AC theories 
on a realistic example.

## Target security game and hardness assumption

Helios is a web-based verifiable election system. Each voter encrypts
their vote under the election public key and posts the resulting
ballot on a public bulletin board. A registrar signs the ballots of
eligible voters: only registered, signed ballots enter the tally. In
homomorphic mode, Helios never decrypts an individual ballot: the
encryption is homomorphic, so the tally multiplies all posted
ciphertexts and decrypts only the product, which yields the sum of
the votes.

Tally integrity says the announced result equals the sum of the
registered votes. Writing `*` for the ciphertext product and `+` for
the vote sum, the n-ballot integrity game runs as follows. The honest
voters cast their ballots, the adversary registers ballots of its own
choice, and finally the adversary submits a board `c1, ..., cn`. The
tally checks that every board ballot carries a valid registrar
signature and that the ballots are pairwise distinct, and the
adversary wins if

    dec(c1 * c2 * ... * cn)  differs from  v1 + v2 + ... + vn,

the sum of the registered votes.

The final oracle of this game processes the whole board: it checks
each ballot and computes an n-fold product and an n-fold sum. Our
oracle bodies are straight-line and cannot do this. We therefore pose
the two-ballot version, with one honest voter and one adversarial
voter. It is a core of the n-ballot game: the adversary's remaining
ballots multiply into a single ciphertext encrypting their vote sum,
so one adversarial ballot can stand for all of them. The game G:

- `ginit` --- samples the registrar key `skR` and the election key `k`;
  publishes both public keys.
- `gvote` --- the honest voter casts, once: samples the vote `v1` and
  randomness `r1`, records them, and publishes the ballot
  `enc(v1, pk(k), r1)` with the registrar's signature.
- `greg` --- the adversarial voter registers, once: the registrar signs
  the submitted ballot and records it as `c2`.
- `gfin` --- the tally: receives a board of two signed ballots,
  `pair(pair(sigA, cA), pair(sigH, cH))`, checks both signatures,
  checks (w.l.o.g.) that the second ballot is the honest one (`cH = c1`), 
  checks that the two ballots differ, decrypts the board product, and declares
  a win if the result differs from the registered sum `v1 + dec(c2)`.

The hard problem H is plain EUF-CMA of the registrar's scheme: winning
G requires a board ballot that passes signature verification although
the registrar never signed it, a forgery.

The main point of the example is the reasoning modulo AC: the win
check compares two sums built in different orders, which agree only
modulo commutativity of the vote sum. The equational theory below
makes this precise.

## Equational theory

Writing `.` for the randomness product, the homomorphism is

    enc(v1, pk, r1) * enc(v2, pk, r2)  =  enc(v1 + v2, pk, r1 . r2)

In the model, `*` is `cmul`, `+` is `vadd_ud`, and `.` is `rmul_ud`
(the `_ud` suffix as in the top-level README); `+` and `.` are
declared AC in `ac.txt`.

The AC algebra is essential. Consider the adversary that does not 
do any forgery: it simply submits the ballot it registered to the board 
(`cA = c2`). Let us write `v2` for its vote `dec(k, c2)`. 
The board product then decrypts to `v2 + v1` (board order),
while the registered sum reads `v1 + v2` (registration order): the
same sum, taken in reverse. A win is a symbolic notion: the game's
checks compare terms modulo the declared equational theory. Without
AC, `vadd(v2, v1)` and `vadd(v1, v2)` are distinct terms, so this
adversary "wins" without producing any forgery, and no reduction to
EUF-CMA exists. Yet a reduction exists modulo AC because then such an 
adversary cannot fool the game into declaring it a winner and the 
adversary must actually forge a ballot signature.

## Modelling notes

- `gvote` and `greg` are call-once, each self-guarded by an emptiness
  check and store on a constant-row cell: the two-voter election has
  one honest vote cast and one voter registration.
- All game state lives at the constant row: `gvote` records the vote
  and the honest ballot, `greg` the registered ballot, and `gfin`
  loads all three directly. In particular the registered ballot is
  known to the game at the tally, so the win check compares against the
  actual registered vote.
- The game fixes the board order: the honest ballot occupies the
  second slot (`cH = c1`), so the adversary's own ballot arrives
  first. A reduction is straight-line code and cannot search the board
  for the forged ballot; fixing its position lets the reduction
  forward the first pair.
- The two-ballot game is the core of the n-ballot statement. Ballots
  aggregate: the product of the honest ballots is one ciphertext
  encrypting their vote sum, and likewise for the adversary's
  registered ballots, so one ballot of each kind stands for many.
  What remains on paper is a counting argument: a board whose product
  differs from the registered sum must contain some individually
  signed ballot outside the registered set, and that single ballot
  fills the `cA` slot.

## Supported backends

tamarin-unchained only: redx rejects the proverif and tamarin backends
upfront for this example ("The current backend does not support
user-defined AC theories"). Run `./redx tamarin-unchained
homomorphic-tally` from `redx/`; the reduction and side conditions
appear at the end of the output, and the run takes a few seconds.

Feeding the emitted model to vanilla Tamarin by hand fails at parse on
the `[AC]` annotation.

WARNING: do not run the emitted model with the ` [AC]` annotations
removed unbounded --- the search diverges and reached 18.9 GB before
the kernel kills it. Wrap it:

    systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0 \
      timeout 300 $REDX_TAMARIN_UNCHAINED --prove <model>

The expected result is no verdict within the bounds. 

## Results and interpretation

### Reduction

The synthesised reduction is the pen-and-paper one. `ginit` calls
`hinit` and publishes H's key as the registrar key, together with an
election key of its own. `gvote` samples the vote and randomness,
builds the honest ballot, and signs it through `hsign`. `greg` forwards
the submitted ballot to `hsign`. `gfin` forwards the first board pair
to `hfin` as the forgery.

### Side-conditions

None.
