def ginit(bot) {
  new ~r0;
  v0 := ocall hinit(bot);
  store L_~r0[botscope] ~r0;
  out pair(hash(sample_key(~r0)), v0);
}

def gpk(i) {
  new ~q0;
  new ~q1;
  store L_v2[i] i;
  store L_~q0[i] ~q0;
  store L_~q1[i] ~q1;
  out pair(hash(sample_key(~q0)), hash(sample_key(~q1)));
}

def gsign(ib) {
  load L_v2[fst(ib)] v2;
  load L_~q0[fst(ib)] ~q0;
  load L_~q1[fst(ib)] ~q1;
  out proj(snd(ib), pair(sample_key(~q0), sample_key(~q1)));
}

def gsignstar(bot2) {
  load L_~r0[botscope] ~r0;
  out sample_key(~r0);
}

def gfin(x) {
  _ := ocall hfin(x);
  out bot;
}