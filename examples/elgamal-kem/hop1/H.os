odef hinit(bot) {
    new rx;
    new ry;
    new rz;
    x := sample_exp(rx);
    y := sample_exp(ry);
    z := sample_exp(rz);
    out pair(expo(g(), x),
             pair(expo(g(), y),
                  diff(expo(expo(g(), x), y), expo(g(), z))));
}
odef hfin(guess) {
    chk guess = diff(zero(),one());
}
