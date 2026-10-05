odef ginit(bot) {
    new rk;
    k := sample_key(rk);
    store Key[botscope()] k;
    out ok();
}
odef genc(x0x1) {
    load Key[botscope()] k;
    new r;
    c := diff(f(enc(fst(x0x1), k, r)), f(enc(snd(x0x1), k, r)));
    out c;
}
odef gfin(guess) {
    chk guess = diff(one(),zero());
}