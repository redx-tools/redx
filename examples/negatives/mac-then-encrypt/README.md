# MAC-then-Encrypt with a malleable cipher

## Target security game and hardness assumption

Thsi is the first hop of an attempted IND-CCA proof of MAC-then-Encrypt
--- ct = enc(kE, r, pair(m, mac(kM, m))) --- the mirror of
encrypt-then-mac/hop1 with only the scheme swapped. 
The target game G bounds the bad event "a valid ciphertext the game never 
issued"; the hard problem H is EUF-CMA of the MAC. 

The MAC-then-Encrypt scheme is not secure (Bellare and Namprempre, 
Asiacrypt 2000) exhibit an IND-CPA but malleable cipher as a counterexample. 

redx synthesises a reduction, but the side-conditions encode the above attack.

## Equational theory

The standard correctness of decryption equation.

## Supported backends

Both proverif and tamarin (a reachability game).

## Results and interpretation

### Reduction

redx synthesises the natural reduction:
R samples kE and the bit itself, MACs through hmac. When it receives 
a 'bad' ciphertext to decrypt --- input ctstar to fin --- it hands
dec(kE, ctstar) to hfin (syntactically it projects the two components 
and recombines them, but semantically it does not matter). 
That wins EUF-CMA only if the message inside
ctstar was never MACed --- which G's win does not guarantee.

### Side-conditions

One instance per `hmac` call — `genc`'s and `gchal`'s — each reading:

    if `c*` decrypts to a validly MACed pair and `c* != c`,
    then `fst(dec(kE, c*)) != m`.

where `c*` represents the adversary's bad call to the decryption
oracle (a ciphertext never issued by `enc`) and
`c := enc(kE, rE, pair(m, mac(kM, m)))` represents the encryption
obtained during any arbitrary call to `genc` (respectively, `gchal`).

In other words: every fresh valid ciphertext must carry a fresh
message — a `c*` that differs from `c` must not decrypt to the
already-MACed `m`. This is a non-malleability property of `enc`. A
malleable cipher, for example, falsifies it: maul `c` into some
`c* != c` with `dec(kE, c*) = pair(m, mac(kM, m))`; the premise holds,
the conclusion fails, and this `c*` is the Bellare--Namprempre forgery
against MAC-then-Encrypt.
