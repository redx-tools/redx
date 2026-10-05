odef ginit(bot) {
    new rsk;
    sk := sample_key(rsk);
    store SKey[botscope()] sk;
    out pk(sk);
}
odef gsign(m) {
    load SKey[botscope()] sk;
    fs := f(sign(sk, m));
    store GSign[m] fs;
    out fs;
}
odef gfin(sm) {
    load SKey[botscope()] sk;
    empty GSign[snd(sm)];
    chk verify(finv(fst(sm)), snd(sm), pk(sk)) = ok();
    win := ok();
}