def ginit(bot) {
  v0 := ocall hinit(bot);
  store L_v0[botscope] v0;
  out fst(v0);
}

def gsign(m) {
  load L_v0[botscope] v0;
  v3 := ocall hsign(xor_ud(m, snd(v0)));
  out v3;
}

def gfin(sm) {
  load L_v0[botscope] v0;
  _ := ocall hfin(pair(fst(sm), xor_ud(snd(v0), snd(sm))));
  out bot;
}