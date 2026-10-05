def ginit(bot_init) {

  out ok;
}

def gkgen_lt(bot_lt) {
  new a;
  store L_a[pk(sample_sk(a))] a;
  out pk(sample_sk(a));
}

def gkgen_curr(bot_curr) {
  ~M_1 := ocall hinit(bot);
  out ~M_1;
}

def gkgen_gt(bot_gt) {
  new a_1;
  store L_a_1[pk(sample_sk(a_1))] a_1;
  out pk(sample_sk(a_1));
}

def gchal_lt(px0x1_lt) {
  load L_a[fst(px0x1_lt)] a;
  new a_2;
  out enc(fst(snd(px0x1_lt)), pk(sample_sk(a)), a_2);
}

def gchal_curr(x0x1_curr) {
  ~M_7 := ocall hlor(x0x1_curr);
  out ~M_7;
}

def gchal_gt(px0x1_gt) {
  load L_a_1[fst(px0x1_gt)] a_1;
  new new-name_2;
  out enc(snd(snd(px0x1_gt)), pk(sample_sk(a_1)), new-name_2);
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}