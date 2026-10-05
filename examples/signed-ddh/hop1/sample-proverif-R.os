def ginit(bot) {
  new a;
  new a_1;
  new a_2;
  ~M_1 := ocall hinit(bot);
  store L_~M_1[botscope] ~M_1;
  store L_a[botscope] a;
  store L_a_1[botscope] a_1;
  store L_a_2[botscope] a_2;
  out pair(pk(sample_key(a)), ~M_1);
}

def AliceFst(botA) {
  load L_a[botscope] a;
  load L_a_1[botscope] a_1;
  out pair(pk(sample_key(a)), expo(g, sample_exp(a_1)));
}

def Bob(x) {
  load L_~M_1[botscope] ~M_1;
  load L_a_2[botscope] a_2;
  ~M_4 := ocall hsign(pair(pair(snd(x), expo(g, sample_exp(a_2))), fst(x)));
  out pair(pair(~M_1, expo(g, sample_exp(a_2))), ~M_4);
}

def AliceSnd(y) {
  load L_~M_1[botscope] ~M_1;
  load L_a[botscope] a;
  load L_a_1[botscope] a_1;
  out ifteq(fst(fst(y)), ~M_1, iteq(verify(pair(pair(expo(g, sample_exp(a_1)), snd(fst(y))), pk(sample_key(a))), snd(y), pk(sample_key(a))), ok, pair(sign(sample_key(a), pair(pair(snd(fst(y)), expo(g, sample_exp(a_1))), ~M_1)), expo(snd(fst(y)), sample_exp(a_1)))));
}

def gfin(yB) {
  load L_a[botscope] a;
  load L_a_1[botscope] a_1;
  _ := ocall hfin(pair(pair(pair(expo(g, sample_exp(a_1)), snd(fst(yB))), pk(sample_key(a))), snd(yB)));
  out bot;
}