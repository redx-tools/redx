odef hinit(bot) {
    new rk;
    k := sample_key(rk);
    store Key[botscope()] k;
}
odef hhash(m) {
    load Key[botscope()] k;
    h := hash(k, m);
    store Hashed[m] ok();
    out h;
}
odef hver(mh) {
    load Key[botscope()] k;
    out verify(fst(mh), snd(mh), k);
}
odef hfin(mhstar) {
    load Key[botscope()] k;
    empty Hashed[fst(mhstar)];
    chk verify(fst(mhstar), snd(mhstar), k) = ok();
    win := ok();
}