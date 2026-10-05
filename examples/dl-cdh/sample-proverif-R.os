def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  store L_~M_1[botscope] ~M_1;
  out snd(~M_1);
}

def gfin(xdash) {
  load L_~M_1[botscope] ~M_1;
  _ := ocall hfin(expo(fst(~M_1), xdash));
  out bot;
}