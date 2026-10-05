odef hinit(bot) {
    new rk;
    k := sample_key(rk);
    store Key[botscope()] k;
    out ok();
}
odef henc(x) {
    load Key[botscope()] k;
    new r;
    c := enc(x, k, r);
    out c;
}
odef hlor(x0x1) {
    empty L[constscope()];
    load Key[botscope()] k;
    new rr;
    c := diff(enc(fst(x0x1), k, rr), enc(snd(x0x1), k, rr));
    store L[constscope()] c;
    out c;
}
odef hfin(guess) {
    chk guess = diff(one(),zero());
}