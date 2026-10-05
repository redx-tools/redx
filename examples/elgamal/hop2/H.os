odef hinit(bot) {
    out ok();
}
odef hpad(m) {
    new rz;
    z := sample_exp(rz);
    out diff(bmul(m, expo(g(), z)), expo(g(), z));
}
odef hfin(guess) {
    chk guess = diff(zero(),one());
}
