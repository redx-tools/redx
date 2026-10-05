odef hinit(bot) {
    new rx2;
    new ry2;
    x2 := sample_exp(rx2);
    y2 := sample_exp(ry2);
    store HX[botscope()] x2;
    store HY[botscope()] y2;
    out pair(expo(g(), x2), expo(g(), y2));
}
odef hfin(zstar) {
    load HX[botscope()] x2;
    load HY[botscope()] y2;
    chk zstar = expo(expo(g(), x2), y2);
    win := ok();
}
