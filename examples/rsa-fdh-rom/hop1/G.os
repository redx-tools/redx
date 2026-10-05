odef ginit(bot) {
    new r;
    store SKey[botscope()] r;
    out pair(N(r), e(r));
}
odef gronew(q) {
    load SKey[botscope()] r;
    empty RO[q];
    empty ROstar[q];
    new rh;
    h := diff(sample_zn(rh), modexp(sample_zn(rh), e(r), N(r)));
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
    empty RO[qstar];
    empty ROstar[qstar];
    new rhstar;
    hstar := diff(sample_zn(rhstar), modexp(sample_zn(rhstar), e(r), N(r)));
    store ROstar[qstar] hstar;
    out hstar;
}
odef grostarold(qq2) {
    load ROstar[qq2] hh2;
    out hh2;
}
odef gfin(guess) {
    chk guess = diff(zero(), one());
}
