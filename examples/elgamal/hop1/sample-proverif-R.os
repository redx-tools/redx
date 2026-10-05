def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  store L_~M_1[botscope] ~M_1;
  out fst(~M_1);
}

def gchal(m0m1) {
  load L_~M_1[botscope] ~M_1;
  new new-name_2;
  out pair(fst(snd(~M_1)), bmul(ifte(sample_bit(new-name_2), snd(m0m1), fst(m0m1)), snd(snd(~M_1))));
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}