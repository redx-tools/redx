odef hinit(bot) {
    new ra;
    new rb;
    a := sample_exp(ra);
    b := sample_exp(rb);
    store SecretA[botscope()] a;
    store SecretB[botscope()] b;
    out pair(expo(g(), a), expo(g(), b));
}
odef hfin(gab) {
    load SecretA[botscope()] a;
    load SecretB[botscope()] b;
    chk gab = expo(g(), mul(a, b));
    win := ok();
}