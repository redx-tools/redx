def ginit(bot) {
  v0 := ocall hinit(bot);
  out ok;
}

def gtag(bot2) {
  new ~n;
  v1 := ocall hhash(~n);
  out pair(~n, v1);
}

def gread(tag) {
  v5 := ocall hver(tag);
  out v5;
}

def gfin(tagstar) {
  _ := ocall hfin(tagstar);
  out bot;
}