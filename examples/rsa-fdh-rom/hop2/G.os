odef ginit(bot) {
    new r;
    new rhstar;
    store SKey[botscope()] r;
    store StarSeed[botscope()] rhstar;
    out pair(N(r), e(r));
}
odef gronew(q) {
    load SKey[botscope()] r;
    empty RO[q];
    empty ROstar[q];
    new rh;
    h := modexp(sample_zn(rh), e(r), N(r));
    store RO[q] h;
    out h;
}
odef groold(qq) {
    load RO[qq] hh;
    out hh;
}
odef gsign(m) {
    load SKey[botscope()] r;
    load RO[m] hm;
    s := modexp(hm, d(r), N(r));
    store Signed[m] ok();
    out s;
}
odef grostar(qstar) {
    load SKey[botscope()] r;
    load StarSeed[botscope()] rhstar;
    empty RO[qstar];
    empty ROstar[qstar];
    hstar := modexp(sample_zn(rhstar), e(r), N(r));
    store ROstar[qstar] hstar;
    out hstar;
}
odef grostarold(qq2) {
    load ROstar[qq2] hh2;
    out hh2;
}
odef gfin(msstar) {
    load SKey[botscope()] r;
    load ROstar[fst(msstar)] hh;
    empty Signed[fst(msstar)];
    chk modexp(snd(msstar), e(r), N(r)) = hh;
    win := ok();
}
