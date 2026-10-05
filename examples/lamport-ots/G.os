odef ginit(bot) {
    new r0;
    new r1;
    s0 := sample_key(r0);
    s1 := sample_key(r1);
    store SKstar[botscope()] pair(s0, s1);
    out pair(hash(s0), hash(s1));
}
odef gpk(i) {
    empty SK[i];
    new q0;
    new q1;
    p := pair(sample_key(q0), sample_key(q1));
    store SK[i] p;
    out pair(hash(fst(p)), hash(snd(p)));
}
odef gsign(ib) {
    load SK[fst(ib)] sk;
    empty Sgn[fst(ib)];
    store Sgn[fst(ib)] snd(ib);
    out proj(snd(ib), sk);
}
odef gsignstar(bot2) {
    load SKstar[botscope()] sk;
    empty Qstar[qscope()];
    store Qstar[qscope()] zero_ud();
    out fst(sk);
}
odef gfin(x) {
    load SKstar[botscope()] sk;
    load Qstar[qscope()] q;
    chk hash(x) = hash(snd(sk));
    win := ok();
}
