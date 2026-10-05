odef ginit(bot) {
    new r;
    skey := sk(r);
    pkey := pk(r);
    store SKey[botscope()] skey;
    store PKey[botscope()] pkey;
    out pkey;
}
// mtriple is of the form pair(pair(m1,m2),m3)
odef gtriplesign(mtriple) {
    load SKey[botscope()] skey;
    m1m2 := fst(mtriple);
    m3 := snd(mtriple);
    s1 := sign(skey, m1m2);
    m3s1 := pair(m3,s1);
    s2 := sign(skey, m3s1);
    sig := pair(s1,s2);
    store Signed[mtriple] sig;
    out sig;
}
// mstriple is of the form pair(mtriple, sig), 
// where mtriple is of the form pair(pair(m1,m2),m3)
// and   sig is of the form pair(s1,s2) 
odef gfin(mstriple) {
    load SKey[botscope()] skey;
    load PKey[botscope()] pkey;
    empty Signed[fst(mstriple)];
    chk verify(fst(snd(mstriple)), fst(fst(mstriple)), pkey) = ok();
    chk verify(snd(snd(mstriple)), pair(snd(fst(mstriple)), fst(snd(mstriple))), pkey) = ok();
    win := ok();
}