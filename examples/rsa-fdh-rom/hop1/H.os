odef hinit(bot) {
    out ok();
}
odef hperm(r) {
    new rz;
    out diff(sample_zn(rz), modexp(sample_zn(rz), e(r), N(r)));
}
odef hfin(guess) {
    chk guess = diff(zero(), one());
}
