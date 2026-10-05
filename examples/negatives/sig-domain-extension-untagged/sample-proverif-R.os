def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  out ~M_1;
}

def gtriplesign(mtriple) {
  ~M_3 := ocall hsign(fst(mtriple));
  ~M_4 := ocall hsign(pair(snd(mtriple), ~M_3));
  out pair(~M_3, ~M_4);
}

def gfin(mstriple) {
  _ := ocall hfin(pair(pair(snd(fst(mstriple)), fst(snd(mstriple))), snd(snd(mstriple))));
  out bot;
}