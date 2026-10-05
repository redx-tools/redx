def ginit(bot) {
  new a;
  ~M_1 := ocall hinit(bot);
  out pair(fst(~M_1), pair(snd(~M_1), sample_key(a)));
}

def gronew(q) {
  new a_1;
  store L_a_1[q] a_1;
  out sample_key(a_1);
}

def groold(qq) {
  load L_a_1[qq] a_1;
  out sample_key(a_1);
}

def gfin(qstar) {
  _ := ocall hfin(qstar);
  out bot;
}