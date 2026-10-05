def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  out ~M_1;
}

def gtriplesign(mtriple) {
  new a;
  ~M_3 := ocall hsign(pair(a, pair(ell, pair(idxone, fst(fst(mtriple))))));
  ~M_4 := ocall hsign(pair(a, pair(ell, pair(idxtwo, snd(fst(mtriple))))));
  ~M_5 := ocall hsign(pair(a, pair(ell, pair(idxthree, snd(mtriple)))));
  out pair(a, pair(~M_3, pair(~M_4, ~M_5)));
}

def gfin(mstriple) {
  _ := ocall hfin(pair(pair(fst(snd(mstriple)), pair(ell, pair(idxtwo, snd(fst(fst(mstriple)))))), fst(snd(snd(snd(mstriple))))));
  out bot;
}