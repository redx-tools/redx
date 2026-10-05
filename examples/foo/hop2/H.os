odef hinit(bot) {
    new sk;
    store Key[botscope()] sk;
    out pk(sk);
}
odef hlor(m0m1) {
    load Key[botscope()] sk;
    new r;
    c := diff(enc(fst(m0m1), pk(sk), r), enc(snd(m0m1), pk(sk), r));
    store Challenged[c] bot();
    out c;
}
odef hdec(c) {
    load Key[botscope()] sk;
    empty Challenged[c];
    out dec(c, sk);
}
odef hfin(guess) {
    chk guess = diff(one(),zero());
}
