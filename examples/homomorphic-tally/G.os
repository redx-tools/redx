odef ginit(bot) {
    new rskR;
    skR := sample_sigkey(rskR);
    new rek;
    k := sample_enckey(rek);
    store RK[botscope()] skR;
    store EK[botscope()] k;
    out pair(pk(skR), pk(k));
}
odef gvote(botv) {
    load RK[botscope()] skR;
    load EK[botscope()] k;
    empty HVote[constscope()];
    new rv;
    v1 := sample_vote(rv);
    new r1;
    c1 := enc(v1, pk(k), r1);
    store HVote[constscope()] v1;
    store HBallot[constscope()] c1;
    out pair(c1, sign(skR, c1));
}
odef greg(c2) {
    load RK[botscope()] skR;
    empty Reg[constscope()];
    store Reg[constscope()] c2;
    out sign(skR, c2);
}
// board is of the form pair(pair(sigA, cA), pair(sigH, cH));
// the checks force cH = c1, so cA is the adversary's own board ballot
odef gfin(board) {
    load RK[botscope()] skR;
    load EK[botscope()] k;
    load HVote[constscope()] v1;
    load HBallot[constscope()] c1;
    load Reg[constscope()] c2;
    chk verify(fst(fst(board)), snd(fst(board)), pk(skR)) = ok();
    chk verify(fst(snd(board)), snd(snd(board)), pk(skR)) = ok();
    chk snd(snd(board)) = c1;
    chk snd(fst(board)) != snd(snd(board));
    chk dec(cmul(snd(fst(board)), snd(snd(board))), k) != vadd_ud(v1, dec(c2, k));
    win := ok();
}
