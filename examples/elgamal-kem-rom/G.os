odef ginit(bot) {
    new rx;
    new ry;
    new rk;
    x := sample_exp(rx);
    y := sample_exp(ry);
    store CellX[botscope()] x;
    store CellY[botscope()] y;
    out pair(expo(g(), x), pair(expo(g(), y), sample_key(rk)));
}

odef gronew(q) {
    empty RO[q];
    new rh;
    h := sample_key(rh);
    store RO[q] h;
    out h;
}

odef groold(qq) {
    load RO[qq] hh;
    out hh;
}

// gfin is nothing but gronew called at a q = g^{xy}.
odef gfin(qstar) {
    load CellX[botscope()] x;
    load CellY[botscope()] y;
    empty RO[qstar];
    chk qstar = expo(expo(g(), x), y);
    win := ok();
}
