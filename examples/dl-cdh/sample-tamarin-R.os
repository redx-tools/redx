def ginit(bot) {
  v0 := ocall hinit(bot);
  store L_v0[botscope] v0;
  out snd(v0);
}

def gfin(xdash) {
  load L_v0[botscope] v0;
  _ := ocall hfin(expo(fst(v0), xdash));
  out bot;
}