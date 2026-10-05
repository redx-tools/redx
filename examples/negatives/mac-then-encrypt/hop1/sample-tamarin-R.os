def ginit(bot) {
  new ~rb;
  new ~rkE;
  v0 := ocall hinit(bot);
  store L_~rb[botscope] ~rb;
  store L_~rkE[botscope] ~rkE;
  out ok;
}

def genc(m) {
  load L_~rkE[botscope] ~rkE;
  new ~rE;
  v3 := ocall hmac(m);
  store L_v2[enc(sample_enckey(~rkE), ~rE, pair(m, v3))] m;
  out enc(sample_enckey(~rkE), ~rE, pair(m, v3));
}

def gchal(chal_m0m1) {
  load L_~rb[botscope] ~rb;
  load L_~rkE[botscope] ~rkE;
  new ~rrE;
  v5 := ocall hmac(ifte(sample_bit(~rb), fst(chal_m0m1), snd(chal_m0m1)));
  out enc(sample_enckey(~rkE), ~rrE, pair(ifte(sample_bit(~rb), fst(chal_m0m1), snd(chal_m0m1)), v5));
}

def gdec(ctdash) {
  load L_v2[ctdash] v2;
  out v2;
}

def gfin(ctstar) {
  load L_~rkE[botscope] ~rkE;
  _ := ocall hfin(dec(sample_enckey(~rkE), ctstar));
  out bot;
}