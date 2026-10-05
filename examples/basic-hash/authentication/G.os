odef ginit(bot) {
    new rk;
    k := sample_key(rk);
    store Key[botscope()] k;
    out ok();
}
odef gtag(bot2) {
    load Key[botscope()] k;
    new n;
    tag := pair(n, hash(k, n));
    store Tagged[n] ok();
    out tag;
}
odef gread(tag) {
    load Key[botscope()] k;
    nread := fst(tag);
    hread := snd(tag);
    out verify(nread, hread, k);
}
odef gfin(tagstar) {
    load Key[botscope()] k;
    empty Tagged[fst(tagstar)];
    chk verify(fst(tagstar), snd(tagstar), k) = ok();
    win := ok();
}