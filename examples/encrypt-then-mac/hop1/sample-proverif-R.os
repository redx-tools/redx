def ginit(bot) {
  new a;
  new a_4;
  ~M_1 := ocall hinit(bot);
  store L_a[botscope] a;
  store L_a_4[botscope] a_4;
  out ok;
}

def genc(m) {
  load L_a[botscope] a;
  new a_1;
  ~M_3 := ocall hmac(enc(sample_enckey(a), a_1, m));
  store L_~M_2[pair(enc(sample_enckey(a), a_1, m), ~M_3)] m;
  out pair(enc(sample_enckey(a), a_1, m), ~M_3);
}

def gchal(chal_m0m1) {
  load L_a[botscope] a;
  load L_a_4[botscope] a_4;
  new a_3;
  ~M_5 := ocall hmac(enc(sample_enckey(a), a_3, ifte(sample_bit(a_4), fst(chal_m0m1), snd(chal_m0m1))));
  out pair(enc(sample_enckey(a), a_3, ifte(sample_bit(a_4), fst(chal_m0m1), snd(chal_m0m1))), ~M_5);
}

def gdec(ctdash) {
  load L_~M_2[ctdash] ~M_2;
  out ~M_2;
}

def gfin(ctstar) {
  _ := ocall hfin(pair(fst(ctstar), snd(ctstar)));
  out bot;
}