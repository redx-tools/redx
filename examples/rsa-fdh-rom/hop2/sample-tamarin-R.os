def ginit(bot) {
  v0 := ocall hinit(bot);
  store L_v0[botscope] v0;
  out pair(fst(fst(v0)), snd(fst(v0)));
}

def gronew(q) {
  load L_v0[botscope] v0;
  new ~rh;
  store L_v2[q] q;
  store L_~rh[q] ~rh;
  out modexp(sample_zn(~rh), snd(fst(v0)), fst(fst(v0)));
}

def groold(qq) {
  load L_v0[botscope] v0;
  load L_~rh[qq] ~rh;
  out modexp(sample_zn(~rh), snd(fst(v0)), fst(fst(v0)));
}

def gsign(m) {
  load L_v2[m] v2;
  load L_~rh[m] ~rh;
  out sample_zn(~rh);
}

def grostar(qstar) {
  load L_v0[botscope] v0;
  out snd(v0);
}

def grostarold(qq2) {
  load L_v0[botscope] v0;
  out snd(v0);
}

def gfin(msstar) {
  _ := ocall hfin(snd(msstar));
  out bot;
}