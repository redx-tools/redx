def ginit(bot) {
  new new-name_2;
  ~M_1 := ocall hinit(bot);
  store L_new-name_2[botscope] new-name_2;
  out pair(N(new-name_2), e(new-name_2));
}

def gronew(q) {
  load L_new-name_2[botscope] new-name_2;
  ~M_3 := ocall hperm(new-name_2);
  store L_~M_3[q] ~M_3;
  store L_~M_4[q] q;
  out ~M_3;
}

def groold(qq) {
  load L_~M_3[qq] ~M_3;
  out ~M_3;
}

def gsign(m) {
  load L_~M_3[m] ~M_3;
  load L_~M_4[m] ~M_4;
  load L_new-name_2[botscope] new-name_2;
  out modexp(~M_3, d(new-name_2), N(new-name_2));
}

def grostar(qstar) {
  load L_new-name_2[botscope] new-name_2;
  ~M_2 := ocall hperm(new-name_2);
  store L_~M_2[qstar] ~M_2;
  out ~M_2;
}

def grostarold(qq2) {
  load L_~M_2[qq2] ~M_2;
  out ~M_2;
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}