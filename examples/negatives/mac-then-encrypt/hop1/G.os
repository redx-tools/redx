odef ginit(bot) {
    new rb;
    new rkE;
    new rkM;
    b := sample_bit(rb);
    kE := sample_enckey(rkE);
    kM := sample_mackey(rkM);
    store SecretBit[botscope()] b;
    store KeyEnc[botscope()] kE;
    store KeyMac[botscope()] kM;
    out ok();
}
odef genc(m) {
    load SecretBit[botscope()] b;
    load KeyMac[botscope()] kM;
    load KeyEnc[botscope()] kE;
    new rE;
    t := mac(kM, m);
    ct := enc(kE, rE, pair(m, t));
    store Encrypted[ct] m;
    out ct;
}
odef gchal(chal_m0m1) {
    load SecretBit[botscope()] b;
    load KeyMac[botscope()] kM;
    load KeyEnc[botscope()] kE;
    m := ifte(b, fst(chal_m0m1), snd(chal_m0m1));
    new rrE;
    tt := mac(kM, m);
    ct := enc(kE, rrE, pair(m, tt));
    store Challenged[ct] ok();
    out ct;
}
odef gdec(ctdash) {
    load KeyMac[botscope()] kM;
    load KeyEnc[botscope()] kE;
    empty Challenged[ctdash];
    chk vermac(fst(dec(kE, ctdash)), snd(dec(kE, ctdash)), kM) = ok();
    load Encrypted[ctdash] v;
    out v;
}
odef gfin(ctstar) {
    load KeyMac[botscope()] kM;
    load KeyEnc[botscope()] kE;
    empty Encrypted[ctstar];
    empty Challenged[ctstar];
    chk vermac(fst(dec(kE, ctstar)), snd(dec(kE, ctstar)), kM) = ok();
    win := ok();
}
