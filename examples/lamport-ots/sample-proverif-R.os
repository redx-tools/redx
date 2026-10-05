def ginit(bot) {
  new a;
  ~M_1 := ocall hinit(bot);
  store L_a[botscope] a;
  out pair(hash(sample_key(a)), ~M_1);
}

def gpk(i) {
  new a_1;
  new a_2;
  store L_~M_2[i] i;
  store L_a_1[i] a_1;
  store L_a_2[i] a_2;
  out pair(hash(sample_key(a_1)), hash(sample_key(a_2)));
}

def gsign(ib) {
  load L_~M_2[fst(ib)] ~M_2;
  load L_a_1[fst(ib)] a_1;
  load L_a_2[fst(ib)] a_2;
  out proj(snd(ib), pair(sample_key(a_1), sample_key(a_2)));
}

def gsignstar(bot2) {
  load L_a[botscope] a;
  out sample_key(a);
}

def gfin(x) {
  _ := ocall hfin(x);
  out bot;
}