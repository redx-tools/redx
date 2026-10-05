odef hinit(bot) {
    new rsk;
    sk := sample_key(rsk);
    new d;
    store lk[botscope()] sk;
    store off[botscope()] d;
    out pair(pk(sk), d);
}
odef hsign(m) {
    load lk[botscope()] sk;
    load off[botscope()] d;
    s := sign(sk, xor_ud(m, d));
    store Sign[m] s;
    out s;
}
odef hfin(sm) {
    load lk[botscope()] sk;
    load off[botscope()] d;
    empty Sign[snd(sm)];
    chk verify(fst(sm), xor_ud(snd(sm), d), pk(sk)) = ok();
    win := ok();
}
