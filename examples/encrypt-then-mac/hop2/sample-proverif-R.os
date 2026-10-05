def ginit(bot) {
  new new-name_2;
  ~M_1 := ocall hinit(bot);
  store L_new-name_2[botscope] new-name_2;
  out ok;
}

def genc(m) {
  load L_new-name_2[botscope] new-name_2;
  ~M_3 := ocall henc(pair(m, m));
  store L_~M_2[pair(~M_3, mac(sample_mackey(new-name_2), ~M_3))] m;
  out pair(~M_3, mac(sample_mackey(new-name_2), ~M_3));
}

def gchal(chal_m0m1) {
  load L_new-name_2[botscope] new-name_2;
  ~M_5 := ocall henc(pair(fst(chal_m0m1), snd(chal_m0m1)));
  out pair(~M_5, mac(sample_mackey(new-name_2), ~M_5));
}

def gdec(ctdash) {
  load L_~M_2[ctdash] ~M_2;
  out ~M_2;
}

def gfin(bguess) {
  _ := ocall hfin(bguess);
  out bot;
}