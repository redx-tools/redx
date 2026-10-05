def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  out pair(fst(~M_1), pair(fst(snd(~M_1)), Ha(snd(snd(~M_1)))));
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}