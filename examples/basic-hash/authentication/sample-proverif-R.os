def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  out ok;
}

def gtag(bot2) {
  new a;
  ~M_2 := ocall hhash(a);
  out pair(a, ~M_2);
}

def gread(tag) {
  ~M_5 := ocall hver(tag);
  out ~M_5;
}

def gfin(tagstar) {
  _ := ocall hfin(pair(fst(tagstar), snd(tagstar)));
  out bot;
}