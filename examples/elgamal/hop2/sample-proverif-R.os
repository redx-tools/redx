def ginit(bot) {
  new a;
  new a_1;
  ~M_1 := ocall hinit(bot);
  store L_a_1[botscope] a_1;
  out expo(g, sample_exp(a));
}

def gchal(m0m1) {
  load L_a_1[botscope] a_1;
  new new-name_2;
  ~M_3 := ocall hpad(ifte(sample_bit(a_1), snd(m0m1), fst(m0m1)));
  out pair(expo(g, sample_exp(new-name_2)), ~M_3);
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}