odef hinit(bot) {
    new r2;
    new rx;
    y := modexp(sample_zn(rx), e(r2), N(r2));
    store HKey[botscope()] r2;
    store HY[botscope()] y;
    out pair(pair(N(r2), e(r2)), y);
}
odef hfin(xstar) {
    load HKey[botscope()] r2;
    load HY[botscope()] y;
    chk modexp(xstar, e(r2), N(r2)) = y;
    win := ok();
}
