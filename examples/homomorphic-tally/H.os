odef hinit(bot) {
    new rsk;
    sk := sample_sigkey(rsk);
    store LK[botscope()] sk;
    out pk(sk);
}
odef hsign(m) {
    load LK[botscope()] sk;
    s := sign(sk, m);
    store Sign[m] s;
    out s;
}
odef hfin(sm) {
    load LK[botscope()] sk;
    empty Sign[snd(sm)];
    chk verify(fst(sm), snd(sm), pk(sk)) = ok();
    win := ok();
}
