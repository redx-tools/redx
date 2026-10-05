# Negative examples

The problems in this directory admit no unconditional reduction: the
target game is insecure, or its security does not follow from the
stated assumption. They check that redx does not manufacture proofs
where the literature says none exists. A negative problem resolves in
one of two ways.

No reduction reported: the attack finder finds no attack on the
compiled problem, so redx outputs no reduction. The expected outputs
record this as a sample-<backend>-R.os containing the single word
"null". This is the outcome for encrypt-and-mac.

Reduction found, side condition falsified: redx outputs a reduction,
sound only under the side conditions generated with it. The known attack 
is often encoded within these side-conditions.
This is the outcome for mac-then-encrypt/hop1, encrypt-then-mac-euf, and
sig-domain-extension-untagged.

Note that, in general, a "null" outcome records that the search failed, 
but this is not a proof that no reduction exists.
