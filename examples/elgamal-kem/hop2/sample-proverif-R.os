def ginit(bot) {
  new a;
  new new-name_2;
  ~M_1 := ocall hinit(bot);
  out pair(expo(g, sample_exp(new-name_2)), pair(expo(g, sample_exp(a)), ~M_1));
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}