def ginit(bot) {
  new ~ra;
  new ~rb;
  new ~rkA;
  v0 := ocall hinit(bot);
  store L_v0[botscope] v0;
  store L_~ra[botscope] ~ra;
  store L_~rb[botscope] ~rb;
  store L_~rkA[botscope] ~rkA;
  out pair(pk(sample_key(~rkA)), v0);
}

def AliceFst(botA) {
  load L_~ra[botscope] ~ra;
  load L_~rkA[botscope] ~rkA;
  out pair(pk(sample_key(~rkA)), expo(g, sample_exp(~ra)));
}

def Bob(x) {
  load L_v0[botscope] v0;
  load L_~rb[botscope] ~rb;
  v4 := ocall hsign(pair(pair(snd(x), expo(g, sample_exp(~rb))), fst(x)));
  out pair(pair(v0, expo(g, sample_exp(~rb))), v4);
}

def AliceSnd(y) {
  load L_v0[botscope] v0;
  load L_~ra[botscope] ~ra;
  load L_~rkA[botscope] ~rkA;
  out ifteq(fst(fst(y)), v0, iteq(verify(pair(pair(expo(g, sample_exp(~ra)), snd(fst(y))), pk(sample_key(~rkA))), snd(y), pk(sample_key(~rkA))), ok, pair(sign(sample_key(~rkA), pair(pair(snd(fst(y)), expo(g, sample_exp(~ra))), v0)), expo(snd(fst(y)), sample_exp(~ra)))));
}

def gfin(yB) {
  load L_~ra[botscope] ~ra;
  load L_~rkA[botscope] ~rkA;
  _ := ocall hfin(pair(pair(pair(expo(g, sample_exp(~ra)), snd(fst(yB))), pk(sample_key(~rkA))), snd(yB)));
  out bot;
}