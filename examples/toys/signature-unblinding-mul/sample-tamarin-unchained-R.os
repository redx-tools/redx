def ginit(bot) {
  v0 := ocall hinit(bot);
  store L_v0[botscope] v0;
  out fst(v0);
}

def gsign(m) {
  load L_v0[botscope] v0;
  v3 := ocall hsign(div_ud(m, snd(v0)));
  out v3;
}

def gfin(sm) {
  load L_v0[botscope] v0;
  _ := ocall hfin(pair(fst(sm), div_ud(snd(sm), snd(v0))));
  out bot;
}