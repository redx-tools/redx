odef hinit(bot) {
    new rkE;
    kE := sample_enckey(rkE);
    store Key[botscope()] kE;
    out ok();
}
odef henc(m0m1) {
    load Key[botscope()] kE;
    chk len(fst(m0m1)) = len(snd(m0m1));
    new rE;
    c := diff(enc(kE, rE, fst(m0m1)), enc(kE, rE, snd(m0m1)));
    out c;
}
odef hfin(bguess) {
    chk bguess = diff(zero(),one());
}