odef ginit(bot) {
    new rx;
    x := sample_exp(rx);
    store Secret[botscope()] x;
    out expo(g(), x);
}
odef gfin(xdash) {
    load Secret[botscope()] x;
    chk x = xdash;
    win := ok();
}