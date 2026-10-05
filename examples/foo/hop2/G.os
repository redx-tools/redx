// Mixnet vote privacy, three ballots (Alice and Bob honest, one
// adversarial), real-or-dummy formulation: in the right world the honest
// ballots encrypt a dummy, while the recorded tally is the same in both
// worlds. The mixnet records honest votes WITHOUT decrypting (their
// ciphertexts are recognised by comparison), and decrypts only the
// adversarial ballot after checking it differs from both honest
// ciphertexts --- the IND-CCA2 usage pattern (decryption oracle with
// challenge exclusion). Target of the flagship FOO example
// (Baelde-Koutsos-Sauvage, hal-05453231).

// Model restriction: we only consider the adversaries that put both Alic and Bob's ballot 
// in the builtin board. 

odef ginit(bot) {
    //Mixnet's encryption keys
    new sk1;
    new sk2;
    store Key1[botscope()] sk1;
    store Key2[botscope()] sk2;

    //Commitement keys
    new kA;
    new kB;
    store KeyA[botscope()] kA;
    store KeyB[botscope()] kB;

    //Blind signature token 
    new tkA;
    new tkB;
    store TkA[botscope()] tkA;
    store TkB[botscope()] tkB;

    //Blinding key 
    new kS;
    store KeySign[botscope()] kS;


    out pair(kS,pair(pk(sk1),pk(sk2)));
}



odef AliceAuth(botAauth) {
    load KeyA[botscope()] kA;
    load TkA[botscope()] tkA;
    load KeySign[botscope()] kS;
    commitA := commit(vA(),kA);
    bA := blind(commitA,pkS(kS),tkA);
    store AliceCommit[constscope()] commitA;
    store AliceBlind[constscope()] bA;
    out bA;
}



odef BobAuth(botBauth) {
    load KeyB[botscope()] kB;
    load TkB[botscope()] tkB;
    load KeySign[botscope()] kS;
    commitB := commit(vB(),kB);
    bB := blind(commitB,pkS(kS),tkB);
    store BobCommit[constscope()] commitB;
    store BobBlind[constscope()] bB;
    out bB;
}


odef Alice1(bsA) {
    empty AliceCtxt1[constscope()];
    load Key1[botscope()] sk1;
    load TkA[botscope()] tkA;
    load KeySign[botscope()] kS;
    load KeyA[botscope()] kA;
    load AliceCommit[constscope()] commitA;

    chk baccepte(commitA,pkS(kS),tkA,bsA) = ok();
    new rA;
    ubA := unblind(commitA,pkS(kS),tkA,bsA);
    ctxtA := enc(dummy(), pk(sk1), rA);
    store AliceCtxt1[constscope()] ctxtA;
    store AliceUb[constscope()] ubA;
    out ctxtA;
}



odef Bob1(bsB) {
    empty AliceCtxt1[constscope()];
    load Key1[botscope()] sk1;
    load TkB[botscope()] tkB;
    load KeySign[botscope()] kS;
    load KeyB[botscope()] kB;
    load BobCommit[constscope()] commitB;

    chk baccepte(commitB,pkS(kS),tkB,bsB) = ok();
    new rB;
    ubB := unblind(commitB,pkS(kS),tkB,bsB);
    ctxtB := enc(dummy(), pk(sk1), rB);
    store BobCtxt1[constscope()] ctxtB;
    store BobUb[constscope()] ubB;
    out ctxtB;
}

odef MixnetCollect1Alice(yA) {
    load AliceCtxt1[constscope()] ctxtA;
    load AliceCommit[constscope()] commitA;
    load AliceUb[constscope()] ubA;
    chk yA = ctxtA;
    store VA[constscope()] pair(commitA,ubA);
    out ok();
}

odef MixnetCollect1Bob(yB) {
    load BobCtxt1[constscope()] ctxtB;
    load BobCommit[constscope()] commitB;
    load AliceUb[constscope()] ubB;
    chk yB = ctxtB;
    store VB[constscope()] pair(commitB,ubB);
    out ok();
}

odef MixnetCollect1Charlie(y1) {
    empty VC[constscope()];
    load Key1[botscope()] sk1;
    load AliceCtxt1[constscope()] ctxtA;
    load BobCtxt1[constscope()] ctxtB;
    chk y1 != ctxtA;
    chk y1 != ctxtB;
    v := dec(y1, sk1);
    store VC[constscope()] v;
    out ok();
}


odef MixnetPublish1(botP) {
    load VA[constscope()] commitA;
    load VB[constscope()] commitB;
    load VC[constscope()] commitC;
    store MixnetPublish1Done[constscope()] done();
    out shuffle(commitA, commitB, commitC);
}


// Model's restriction : Alice and Bob find their commits in the Builtin board.
odef BBset(bb) {
    load MixnetPublish1Done[constscope()] dummy;
    load AliceCommit[constscope()] commitA;    
    load BobCommit[constscope()] commitB;
    chk voted(commitA,bb) = ok();
    chk voted(commitB,bb) = ok();
    store BBA[constscope()] bb;
    store BBB[constscope()] bb;
    store BBsetDone[constscope()] ok();
    out ok();
}

odef Alice2(botAlice2) {
    load BBsetDone[constscope()] dummy;
    load AliceCommit[constscope()] commitA;
    load BBA[constscope()] bb;
    load KeyA[botscope()] kA;
    load Key2[botscope()] sk2;
    //store BBA[constscope()] bb;
    store Alice2CheckDone[constscope()] ok();
    new rA2;
    iA := index(commitA,bb);
    ctxtA := diff(enc(pair(iA,kA), pk(sk2),rA2),enc(dummy(), pk(sk2),rA2));
    store AliceCtxt2[constscope()] ctxtA;
    out ctxtA;
}

odef Bob2(botBob2) {
    load BBsetDone[constscope()] dummy;
    load BobCommit[constscope()] commitB;
    load BBB[constscope()] bb;
    load KeyB[botscope()] kB;
    load Key2[botscope()] sk2;
    store Bob2CheckDone[constscope()] ok();
    new rB2;
    iB := index(commitB,bb);
    ctxtB := diff(enc(pair(iB,kB), pk(sk2),rB2),enc(dummy(), pk(sk2),rB2));
    store BobCtxt2[constscope()] ctxtB;
    out ctxtB;
}



odef MixnetCollect2Alice(zA) {
    load AliceCtxt2[constscope()] ctxtA;
    load BBA[constscope()] bb;
    load AliceCommit[constscope()] commitA;
    load KeyA[botscope()] kA;
    //load AliceCommit[constscope()] commitA;
    chk zA = ctxtA;
    iA := index(commitA,bb);
    store ZA[constscope()] pair(iA,kA);
    out ok();
}


odef MixnetCollect2Bob(zB) {
    load BobCtxt2[constscope()] ctxtB;
    load BBB[constscope()] bb;
    load BobCommit[constscope()] commitB;
    load KeyB[botscope()] kB;
    //load AliceCommit[constscope()] commitB;
    chk zB = ctxtB;
    iB := index(commitB,bb);
    store ZB[constscope()] pair(iB,kB);
    out ok();
}

odef MixnetCollect2Charlie(zC) {
    empty ZC[constscope()];
    load Key2[botscope()] sk2;
    load AliceCtxt2[constscope()] ctxtA;
    load BobCtxt2[constscope()] ctxtB;
    chk zC != ctxtA;
    chk zC != ctxtB;
    v := dec(zC, sk2);
    store ZC[constscope()] v;
    out ok();
}

odef MixnetPublish2(botP2) {
    load ZA[constscope()] kcA;
    load ZB[constscope()] kcB;
    load ZC[constscope()] kcC;
    //store MixnetPublish1Done[constscope()] done();
    out shuffle(kcA, kcB, kcC);
}

odef gfin(guess) {
    chk guess = diff(one(),zero());
}
