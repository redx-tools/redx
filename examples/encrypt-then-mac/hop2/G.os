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
    t := mac(kM, c);
    ct := pair(c,t);
    store Encrypted[ct] m;
    out ct;
}
odef gchal(chal_m0m1) {
    load KeyMac[botscope()] kM;
    load KeyEnc[botscope()] kE;
    chk len(fst(chal_m0m1)) = len(snd(chal_m0m1));
    m := diff(fst(chal_m0m1), snd(chal_m0m1));
    new rrE;
    c := enc(kE, rrE, m);
    t := mac(kM, c);
    ct := pair(c,t);
    store Challenged[ct] ok();
    out ct;
}
odef gdec(ctdash) {
    load KeyMac[botscope()] kM;
    load KeyEnc[botscope()] kE;
    empty Challenged[ctdash];
    chk vermac(fst(ctdash), snd(ctdash), kM) = ok();
    load Encrypted[ctdash] v;
    out v;
}
odef gfin(bguess) {
    chk bguess = diff(zero(),one());
}