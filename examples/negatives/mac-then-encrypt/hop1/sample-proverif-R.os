def ginit(bot) {
  new a_1;
  new a_3;
  ~M_1 := ocall hinit(bot);
  store L_a_1[botscope] a_1;
  store L_a_3[botscope] a_3;
  out ok;
}

def genc(m) {
  load L_a_1[botscope] a_1;
  new a_2;
  ~M_3 := ocall hmac(m);
  store L_~M_2[enc(sample_enckey(a_1), a_2, pair(m, ~M_3))] m;
  out enc(sample_enckey(a_1), a_2, pair(m, ~M_3));
}

def gchal(chal_m0m1) {
  load L_a_1[botscope] a_1;
  load L_a_3[botscope] a_3;
  new a_5;
  ~M_5 := ocall hmac(ifte(sample_bit(a_3), fst(chal_m0m1), snd(chal_m0m1)));
  out enc(sample_enckey(a_1), a_5, pair(ifte(sample_bit(a_3), fst(chal_m0m1), snd(chal_m0m1)), ~M_5));
}

def gdec(ctdash) {
  load L_~M_2[ctdash] ~M_2;
  out ~M_2;
}

def gfin(ctstar) {
  load L_a_1[botscope] a_1;
  _ := ocall hfin(pair(fst(dec(sample_enckey(a_1), ctstar)), snd(dec(sample_enckey(a_1), ctstar))));
  out bot;
}