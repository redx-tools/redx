odef hinit(bot) {
    new rsk;
    sk := sample_key(rsk);
    new rd;
    d := sample_grp(rd);
    store lk[botscope()] sk;
    store blind[botscope()] d;
    out pair(pk(sk), d);
}
odef hsign(m) {
    load lk[botscope()] sk;
    load blind[botscope()] d;
    s := sign(sk, mul_ud(d, m));
    store Sign[m] s;
    out s;
}
odef hfin(sm) {
    load lk[botscope()] sk;
    load blind[botscope()] d;
    empty Sign[snd(sm)];
    chk verify(fst(sm), mul_ud(d, snd(sm)), pk(sk)) = ok();
    win := ok();
}
