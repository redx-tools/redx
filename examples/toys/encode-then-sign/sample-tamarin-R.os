def ginit(bot) {
  v0 := ocall hinit(bot);
  out v0;
}

def gsign(m) {
  v3 := ocall hsign(f(m));
  out v3;
}

def gfin(sm) {
  _ := ocall hfin(pair(fst(sm), f(snd(sm))));
  out bot;
}