odef hinit(bot) {
    new rsk;
    sk := sample_key(rsk);
    store lk[botscope()] sk;
    out pk(sk);
}
odef hsign(m) {
    load lk[botscope()] sk;
    s := sign(sk, m);
    store Sign[m] s;
    out s;
}
odef hfin(sm) {
    load lk[botscope()] sk;
    empty Sign[snd(sm)];
    chk verify(fst(sm), snd(sm), pk(sk)) = ok();
    win := ok();
}