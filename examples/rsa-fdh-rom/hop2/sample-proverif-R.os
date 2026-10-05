def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  store L_~M_1[botscope] ~M_1;
  out fst(~M_1);
}

def gronew(q) {
  load L_~M_1[botscope] ~M_1;
  new a;
  store L_~M_2[q] q;
  store L_a[q] a;
  out modexp(sample_zn(a), snd(fst(~M_1)), fst(fst(~M_1)));
}

def groold(qq) {
  load L_~M_1[botscope] ~M_1;
  load L_a[qq] a;
  out modexp(sample_zn(a), snd(fst(~M_1)), fst(fst(~M_1)));
}

def gsign(m) {
  load L_~M_2[m] ~M_2;
  load L_a[m] a;
  out sample_zn(a);
}

def grostar(qstar) {
  load L_~M_1[botscope] ~M_1;
  out snd(~M_1);
}

def grostarold(qq2) {
  load L_~M_1[botscope] ~M_1;
  out snd(~M_1);
}

def gfin(msstar) {
  _ := ocall hfin(snd(msstar));
  out bot;
}