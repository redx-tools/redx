odef hinit(bot) {
    new rsk;
    sk := sample_key(rsk);
    store SKey[botscope()] sk;
    out pk(sk);
}
odef hsign(m) {
    load SKey[botscope()] sk;
    s := sign(sk, m);
    store Sign[m] s;
    out s;
}
odef hfin(sm) {
    load SKey[botscope()] sk;
    empty Sign[snd(sm)];
    chk verify(fst(sm), snd(sm), pk(sk)) = ok();
    win := ok();
}