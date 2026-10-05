odef ginit(bot) {
    new rs;
    new rr;
    new rz;
    s := sample_exp(rs);
    r := sample_exp(rr);
    z := sample_exp(rz);
    pk := expo(g(), s);
    out pair(pk,
             pair(expo(g(), r),
                  diff(Ha(expo(pk, r)), Ha(expo(g(), z)))));
}
odef gfin(guess) {
    chk guess = diff(zero(),one());
}
