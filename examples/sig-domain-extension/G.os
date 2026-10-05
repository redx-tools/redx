odef ginit(bot) {
    new r;
    skey := sk(r);
    pkey := pk(r);
    store SKey[botscope()] skey;
    store PKey[botscope()] pkey;
    out pkey;
}
// mtriple is of the form pair(pair(m1,m2),m3);
// each block is signed as rid || length || index || block
odef gtriplesign(mtriple) {
    load SKey[botscope()] skey;
    new rid;
    m1 := fst(fst(mtriple));
    m2 := snd(fst(mtriple));
    m3 := snd(mtriple);
    s1 := sign(skey, pair(rid, pair(ell(), pair(idxone(), m1))));
    s2 := sign(skey, pair(rid, pair(ell(), pair(idxtwo(), m2))));
    s3 := sign(skey, pair(rid, pair(ell(), pair(idxthree(), m3))));
    sig := pair(rid, pair(s1, pair(s2, s3)));
    store Signed[mtriple] sig;
    out sig;
}
// mstriple is of the form pair(mtriple, sig),
// where mtriple is of the form pair(pair(m1,m2),m3)
// and   sig is of the form pair(rid, pair(s1, pair(s2, s3)));
// verification rebuilds each block message rid || length || index || block
// from the claimed rid and the forged triple, and checks the i-th signature
// against the i-th rebuilt message (the textbook block-count check d' = d
// is structural: triples have fixed arity)
odef gfin(mstriple) {
    load SKey[botscope()] skey;
    load PKey[botscope()] pkey;
    empty Signed[fst(mstriple)];
    // verify(s1, rid || ell || idxone || m1, pkey) = ok
    chk verify(fst(snd(snd(mstriple))), pair(fst(snd(mstriple)), pair(ell(), pair(idxone(), fst(fst(fst(mstriple)))))), pkey) = ok();
    // verify(s2, rid || ell || idxtwo || m2, pkey) = ok
    chk verify(fst(snd(snd(snd(mstriple)))), pair(fst(snd(mstriple)), pair(ell(), pair(idxtwo(), snd(fst(fst(mstriple)))))), pkey) = ok();
    // verify(s3, rid || ell || idxthree || m3, pkey) = ok
    chk verify(snd(snd(snd(snd(mstriple)))), pair(fst(snd(mstriple)), pair(ell(), pair(idxthree(), snd(fst(mstriple))))), pkey) = ok();
    win := ok();
}
