odef ginit(bot) {
    // Initiating Alice and Bob's signing key, nonces for DDH-exchanges,
    // and the ideal-world exponent k. All challenge randomness is
    // sampled eagerly here so that H's names (sampled at hinit) home to
    // this phase.
    new rkA;
    kA := sample_key(rkA);
    new rkB;
    kB := sample_key(rkB);
    new ra;
    new rb;
    new rk;
    a := sample_exp(ra);
    b := sample_exp(rb);
    k := sample_exp(rk);
    store KeyA[botscope()] kA;
    store KeyB[botscope()] kB;
    store NonceA[botscope()] a;
    store NonceB[botscope()] b;
    store NonceK[botscope()] k;
    out pair(pk(kA), pk(kB));  // was pair(kA,kB): leaked the signing keys
}


// Alice starts the exchange by sending both her public keys (signing and DDH)

odef AliceFst(botA) {
    load KeyA[botscope()] kA;
    load NonceA[botscope()] a;
    store AliceFst[constscope()] ok();
    ga := expo(g(), a);
    s := pair(pk(kA), ga);
    out s;
}

odef Bob(x) {
    load KeyB[botscope()] kB;
    load NonceB[botscope()] b;
        
    pkA := fst(x);
    ga := snd(x);
    gb := expo(g(), b);
    p := pair(pk(kB), gb);
    pa := pair( pair(ga,gb), pkA);
    s := sign(kB,pa);
    
    out pair(p,s);
}


odef AliceSnd(y) {
    load KeyA[botscope()] kA;
    load KeyB[botscope()] kB;
    load NonceA[botscope()] a;
    load NonceB[botscope()] b;
    load NonceK[botscope()] k;
    load AliceFst[constscope()] dummy; // ensure AliceFst has run before

    // Guard of Alice's response: checking the received signature.
    // Computable by the adversary, as all data used are public.
    chk fst(fst(y)) = pk(kB);
    chk verify( pair( pair( expo(g(),a), snd(fst(y))), pk(kA)), snd(y), pk(kB)) = ok();

    // From the previous hop, we know that snd(fst(y)) = g^b
    chk snd(fst(y)) = expo(g(),b);

    gk := expo(g(),k);
    gb := expo(g(),b);
    ga := expo(g(), a);
    sB := snd(y);
    pkA := pk(kA); 
    p := pair(ga,gb);
    m := pair(p,pkA);

    sA := sign(kA,pair(pair(gb,ga),pk(kB)));
    key := expo(gb,a);
    
    //guard-one 
    //Real scenario
    chal := diff(key,gk) ;    
    out pair(sA,chal);

}

odef gfin(guess) {
        chk guess = diff(zero(),one());
}

