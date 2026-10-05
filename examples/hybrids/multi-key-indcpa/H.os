odef hinit(bot) {
    new rk;
    p := pk(sample_sk(rk));
    store PKstar[botscope()] p;
    out p;
}

odef hlor(x0x1) {
    empty L[constscope()];
    load PKstar[botscope()] p;
    new rr;
    c := diff(enc(fst(x0x1), p, rr), enc(snd(x0x1), p, rr));
    store L[constscope()] c;
    out c;
}

odef hfin(guess) {
    chk guess = diff(one(),zero());
}
