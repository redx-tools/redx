odef ginit(bot_init) {
    out ok();
}

odef gkgen_lt(bot_lt) {
    new rk_lt;
    p := pk(sample_sk(rk_lt));
    store PKlt[p] ok();
    out p;
}

odef gkgen_curr(bot_curr) {
    empty CurrKey[constscope()];
    new rk_curr;
    p_curr := pk(sample_sk(rk_curr));
    store CurrKey[constscope()] p_curr;
    out p_curr;
}

odef gkgen_gt(bot_gt) {
    new rk_gt;
    p := pk(sample_sk(rk_gt));
    store PKgt[p] ok();
    out p;
}

// Challenge oracles take pair(pk, pair(x0, x1)) for lt/gt keys; the
// current key's challenge loads the stored current pk instead.

odef gchal_lt(px0x1_lt) {
    load PKlt[fst(px0x1_lt)] reg_lt;
    empty Chald_lt[fst(px0x1_lt)];
    new r_lt;
    c := enc(fst(snd(px0x1_lt)), fst(px0x1_lt), r_lt);
    store Chald_lt[fst(px0x1_lt)] ok();
    out c;
}

odef gchal_curr(x0x1_curr) {
    empty Done[constscope()];
    load CurrKey[constscope()] p;
    new r_curr;
    c := diff(enc(fst(x0x1_curr), p, r_curr),
              enc(snd(x0x1_curr), p, r_curr));
    store Done[constscope()] bot();
    out c;
}

odef gchal_gt(px0x1_gt) {
    load PKgt[fst(px0x1_gt)] reg_gt;
    empty Chald_gt[fst(px0x1_gt)];
    new r_gt;
    c := enc(snd(snd(px0x1_gt)), fst(px0x1_gt), r_gt);
    store Chald_gt[fst(px0x1_gt)] ok();
    out c;
}

odef gfin(guess) {
    chk guess = diff(one(),zero());
}
