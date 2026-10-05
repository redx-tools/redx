def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  out ~M_1;
}

def gsign(m) {
  ~M_3 := ocall hsign(m);
  out f(~M_3);
}

def gfin(sm) {
  _ := ocall hfin(pair(finv(fst(sm)), snd(sm)));
  out bot;
}