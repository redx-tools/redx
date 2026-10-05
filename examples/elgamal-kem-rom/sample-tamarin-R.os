def ginit(bot) {
  new ~rk;
  v0 := ocall hinit(bot);
  out pair(fst(v0), pair(snd(v0), sample_key(~rk)));
}

def gronew(q) {
  new ~rh;
  store L_~rh[q] ~rh;
  out sample_key(~rh);
}

def groold(qq) {
  load L_~rh[qq] ~rh;
  out sample_key(~rh);
}

def gfin(qstar) {
  _ := ocall hfin(qstar);
  out bot;
}