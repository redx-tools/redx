def ginit(bot) {
  ~M_1 := ocall hinit(bot);
  out ok;
}

def genc(x) {
  ~M_3 := ocall henc(x);
  out ~M_3;
}

def gchal_lt(x0x1_lt) {
  ~M_5 := ocall henc(fst(x0x1_lt));
  out ~M_5;
}

def gchal_curr(x0x1_curr) {
  ~M_7 := ocall hlor(pair(fst(x0x1_curr), snd(x0x1_curr)));
  out ~M_7;
}

def gchal_gt(x0x1_gt) {
  ~M_9 := ocall henc(snd(x0x1_gt));
  out ~M_9;
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}