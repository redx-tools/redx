odef ginit(bot) {
    new rkE;
    new rkM;
    kE := sample_enckey(rkE);
    kM := sample_mackey(rkM);
    store KeyEnc[botscope()] kE;
    store KeyMac[botscope()] kM;
    out ok();
}
odef genc(m) {
    load KeyMac[botscope()] kM;
    load KeyEnc[botscope()] kE;
    new rE;
    c := enc(kE, rE, m);
    t := mac(kM, m);
    out pair(c, t);
}
odef gchal(chal_m0m1) {
    load KeyMac[botscope()] kM;
    load KeyEnc[botscope()] kE;
    m := diff(fst(chal_m0m1), snd(chal_m0m1));
    new rrE;
    c := enc(kE, rrE, m);
    t := mac(kM, m);
    out pair(c, t);
}
odef gfin(bguess) {
    chk bguess = diff(zero(),one());
}
