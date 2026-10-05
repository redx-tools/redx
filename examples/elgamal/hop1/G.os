odef ginit(bot) {
    new rs;
    s := sample_exp(rs);
    store Key[botscope()] s;
    out expo(g(), s);
}
odef gchal(m0m1) {
    empty Done[constscope()];
    load Key[botscope()] s;
    new rb;
    new rchal;
    new zchal;
    b := sample_bit(rb);
    r := sample_exp(rchal);
    z := sample_exp(zchal);
    store Done[constscope()] bot();
    out pair(expo(g(), r),
             bmul(ifte(b, snd(m0m1), fst(m0m1)),
                  diff(expo(expo(g(), s), r), expo(g(), z))));
}
odef gfin(guess) {
    chk guess = diff(zero(),one());
}
