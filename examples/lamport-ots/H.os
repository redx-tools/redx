odef hinit(bot) {
    new rs;
    s := sample_key(rs);
    store Preimage[botscope()] s;
    out hash(s);
}
odef hfin(x) {
    load Preimage[botscope()] s;
    chk hash(x) = hash(s);
    win := ok();
}
