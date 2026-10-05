def ginit(bot) {
  new ~rek;
  v0 := ocall hinit(bot);
  store L_~rek[botscope] ~rek;
  out pair(v0, pk(sample_enckey(~rek)));
}

def gvote(botv) {
  load L_~rek[botscope] ~rek;
  new ~r1;
  new ~rv;
  v1 := ocall hsign(enc(sample_vote(~rv), pk(sample_enckey(~rek)), ~r1));
  out pair(enc(sample_vote(~rv), pk(sample_enckey(~rek)), ~r1), v1);
}

def greg(c2) {
  v5 := ocall hsign(c2);
  out v5;
}

def gfin(board) {
  _ := ocall hfin(fst(board));
  out bot;
}