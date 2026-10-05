odef hinit(bot) {
    new r;
    skey := sk(r);
    pkey := pk(r);
    store SKey[botscope()] skey;
    store PKey[botscope()] pkey;
    out pkey;
}
odef hsign(m) {
    load SKey[botscope()] skey;
    s := sign(skey, m);
    store Signed[m] s;
    out s;
}
odef hfin(ms) {
    load SKey[botscope()] skey;
    load PKey[botscope()] pkey;
    empty Signed[fst(ms)];
    chk verify(snd(ms), fst(ms), pkey) = ok();
    win := ok();
}