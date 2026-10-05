def ginit(bot) {
  new a;
  new new-name_2;
  ~M_1 := ocall hinit(bot);
  store L_~M_1[botscope] ~M_1;
  store L_a[botscope] a;
  store L_new-name_2[botscope] new-name_2;
  out pair(pk(sample_key(new-name_2)), pk(sample_key(a)));
}

def AliceFst(botA) {
  load L_~M_1[botscope] ~M_1;
  load L_new-name_2[botscope] new-name_2;
  out pair(pk(sample_key(new-name_2)), fst(snd(~M_1)));
}

def Bob(x) {
  load L_~M_1[botscope] ~M_1;
  load L_a[botscope] a;
  out pair(pair(pk(sample_key(a)), fst(~M_1)), sign(sample_key(a), pair(pair(snd(x), fst(~M_1)), fst(x))));
}

def AliceSnd(y) {
  load L_~M_1[botscope] ~M_1;
  load L_a[botscope] a;
  load L_new-name_2[botscope] new-name_2;
  out pair(sign(sample_key(new-name_2), pair(pair(fst(~M_1), fst(snd(~M_1))), pk(sample_key(a)))), snd(snd(~M_1)));
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}