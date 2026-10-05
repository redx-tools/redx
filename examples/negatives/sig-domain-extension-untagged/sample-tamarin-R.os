def ginit(bot) {
  v0 := ocall hinit(bot);
  out v0;
}

def gtriplesign(mtriple) {
  v3 := ocall hsign(fst(mtriple));
  v4 := ocall hsign(pair(snd(mtriple), v3));
  out pair(v3, v4);
}

def gfin(mstriple) {
  _ := ocall hfin(pair(fst(fst(mstriple)), fst(snd(mstriple))));
  out bot;
}