odef ginit(bot) {
    new sk;
    store Key[botscope()] sk;
    out pk(sk);
}

odef Alice(botA) {
    empty AliceCtxt[constscope()];
    load Key[botscope()] sk;
    new rA;
    cA := diff(enc(v0(), pk(sk), rA), enc(dummy(), pk(sk), rA));
    store AliceCtxt[constscope()] cA;
    out cA;
}

odef Bob(botB) {
    empty BobCtxt[constscope()];
    load Key[botscope()] sk;
    new rB;
    cB := diff(enc(v1(), pk(sk), rB), enc(dummy(), pk(sk), rB));
    store BobCtxt[constscope()] cB;
    out cB;
}

odef MixnetCollectAlice(yA) {
    load AliceCtxt[constscope()] cA;
    chk yA = cA;
    store VA[constscope()] v0();
    out ok();
}

odef MixnetCollectBob(yB) {
    load BobCtxt[constscope()] cB;
    chk yB = cB;
    store VB[constscope()] v1();
    out ok();
}

odef MixnetCollect(y) {
    load Key[botscope()] sk;
    load AliceCtxt[constscope()] cA;
    load BobCtxt[constscope()] cB;
    chk y != cA;
    chk y != cB;
    v := dec(y, sk);
    store VC[constscope()] v;
    out ok();
}

odef MixnetPublish(botP) {
    load VA[constscope()] vA;
    load VB[constscope()] vB;
    load VC[constscope()] vC;
    out shuffle(vA, vB, vC);
}

odef gfin(guess) {
    chk guess = diff(one(),zero());
}
