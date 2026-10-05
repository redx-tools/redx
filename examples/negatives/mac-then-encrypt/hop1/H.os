odef hinit(bot) {
    new rkM;
    kM := sample_mackey(rkM);
    store Key[botscope()] kM;
}
odef hmac(m) {
    load Key[botscope()] kM;
    t := mac(kM, m);
    store Macd[m] ok();
    out t;
}
odef hver(mt) {
    load Key[botscope()] kM;
    out vermac(fst(mt), snd(mt), kM);
}
odef hfin(mtstar) {
    load Key[botscope()] kM;
    empty Macd[fst(mtstar)];
    chk vermac(fst(mtstar), snd(mtstar), kM) = ok();
    win := ok();
}