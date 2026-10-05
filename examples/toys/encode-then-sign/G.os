odef ginit(bot) {
    new rsk;
    sk := sample_key(rsk);
    store lk[botscope()] sk;
    out pk(sk);
}
odef gsign(m) {
    load lk[botscope()] sk;
    s := sign(sk, f(m));
    store GSign[m] s;
    out s;
}
odef gfin(sm) {
    load lk[botscope()] sk;
    empty GSign[snd(sm)];
    chk verify(fst(sm), f(snd(sm)), pk(sk)) = ok();
    win := ok();
}