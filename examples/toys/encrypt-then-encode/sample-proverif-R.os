def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  out ok;
}

def genc(x0x1) {
  ~M_3 := ocall henc(pair(fst(x0x1), snd(x0x1)));
  out f(~M_3);
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}