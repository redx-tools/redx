odef ginit(bot) {
    new rs;
    new rb;
    s := sample_exp(rs);
    b := sample_bit(rb);
    store Bit[botscope()] b;
    out expo(g(), s);
}
odef gchal(m0m1) {
    load Bit[botscope()] b;
    new rr;
    new rz;
    r := sample_exp(rr);
    z := sample_exp(rz);
    out diff(pair(expo(g(), r), bmul(ifte(b, snd(m0m1), fst(m0m1)), expo(g(), z))),
             pair(expo(g(), r), expo(g(), z)));
}
odef gfin(guess) {
    chk guess = diff(zero(),one());
}
