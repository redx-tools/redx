def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  out ~M_1;
}

def Alice(botA) {
  ~M_3 := ocall hlor(pair(v0, dummy));
  out ~M_3;
}

def Bob(botB) {
  ~M_2 := ocall hlor(pair(v1, dummy));
  out ~M_2;
}

def MixnetCollectAlice(yA) {

  out ok;
}

def MixnetCollectBob(yB) {

  out ok;
}

def MixnetCollect(y) {
  ~M_9 := ocall hdec(y);
  store L_~M_9[constscope] ~M_9;
  out ok;
}

def MixnetPublish(botP) {
  load L_~M_9[constscope] ~M_9;
  out shuffle(v0, v1, ~M_9);
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}