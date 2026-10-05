odef ginit(bot) {
    new rs;
    new rr;
    new rz;
    new rk;
    out pair(expo(g(), sample_exp(rs)),
             pair(expo(g(), sample_exp(rr)),
                  diff(Ha(expo(g(), sample_exp(rz))), sample_key(rk))));
}
odef gfin(guess) {
    chk guess = diff(zero(),one());
}
