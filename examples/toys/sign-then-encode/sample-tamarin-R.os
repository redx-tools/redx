def ginit(bot) {
  v0 := ocall hinit(bot);
  out v0;
}

def gsign(m) {
  v3 := ocall hsign(m);
  out f(v3);
}

def gfin(sm) {
  _ := ocall hfin(pair(finv(fst(sm)), snd(sm)));
  out bot;
}