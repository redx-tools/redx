odef hinit(bot) {
    new rx;
    new rk;
    out diff(Ha(expo(g(), sample_exp(rx))), sample_key(rk));
}
odef hfin(guess) {
    chk guess = diff(zero(),one());
}
