odef ginit(bot) {
   // Initiating Alice and Bob's signing key, and nonce for DDH-exchanges
    new rkA;
    kA := sample_key(rkA);
    new rkB;
    kB := sample_key(rkB);
    new ra;
    a := sample_exp(ra);
    new rb;
    b := sample_exp(rb);
    store KeyA[botscope()] kA;
    store KeyB[botscope()] kB;
    store NonceA[botscope()] a;
    store NonceB[botscope()] b;
    out pair(pk(kA),pk(kB));
}


// Alice start the exchange by sending both her public key (singing and ddh)

odef AliceFst(botA) {
    load KeyA[botscope()] kA;
    load NonceA[botscope()] a;
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

    //Storing input at Alice for the final oracle
    store Input[constscope()] y;
    
    gb := snd(fst(y));
    ga := expo(g(), a);
    sB := snd(y);
    pkA := pk(kA); 
    p := pair(ga,gb);
    m := pair(p,pkA);
    sb := snd(y);
    v := verify(m,sb,pkA);
    pkB := fst(fst(y));
    store GB[constscope()] gb;
    sA := sign(kA,pair(pair(gb,ga),pk(kB)));
    key := expo(gb,a);
    
    //guard-one 
    //Real scenario
    chal := key ;
    o := pair(sA,chal) ;

    guard := ifteq(pkB, pk(kB), iteq(v,ok(),o) );
    
    out guard;

}


odef gfin(yB) {

   load KeyA[botscope()] kA;
   load KeyB[botscope()] kB;
   load NonceA[botscope()] a;
   load NonceB[botscope()] b;

   
   // Alice's checks return ok
   chk fst(fst(yB)) = pk(kB); 
   chk verify( pair( pair( expo(g(),a),snd(fst(yB)) ) , pk(kA)) , snd(yB), pk(kB)) = ok() ; 
   // Alice's input not
   
   chk snd(fst(yB)) != expo(g(),b); 
   
   win := ok();
       
}

