def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  out ~M_1;
}

def gsign(m) {
  ~M_3 := ocall hsign(f(m));
  out ~M_3;
}

def gfin(sm) {
  _ := ocall hfin(pair(fst(sm), f(snd(sm))));
  out bot;
}