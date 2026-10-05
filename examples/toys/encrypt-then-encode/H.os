odef hinit(bot) {
    new rk;
    k := sample_key(rk);
    store Key[botscope()] k;
    out ok();
}
odef henc(x0x1) {
    load Key[botscope()] k;
    new r;
    c := diff(enc(fst(x0x1), k, r), enc(snd(x0x1), k, r));
    out c;
}
odef hfin(guess) {
    chk guess = diff(one(),zero());
}