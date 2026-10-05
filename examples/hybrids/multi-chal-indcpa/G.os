odef ginit(bot) {
    new rk;
    k := sample_key(rk);
    store Key[botscope()] k;
    out ok();
}

odef genc(x) {
    load Key[botscope()] k;
    new r;
    c := enc(x, k, r);
    out c;
}

odef gchal_lt(x0x1_lt) {
    load Key[botscope()] k;
    new r_lt;
    c := enc(fst(x0x1_lt), k, r_lt);
    out c;
}

odef gchal_curr(x0x1_curr) {
    empty Done[constscope()];
    load Key[botscope()] k;
    new r_curr;
    c := diff(enc(fst(x0x1_curr), k, r_curr), 
              enc(snd(x0x1_curr), k, r_curr));
    store Done[constscope()] bot();
    out c;
}

odef gchal_gt(x0x1_gt) {
    load Key[botscope()] k;
    new r_gt;
    c := enc(snd(x0x1_gt), k, r_gt);
    out c;
}

odef gfin(guess) {
    chk guess = diff(one(),zero());
}
