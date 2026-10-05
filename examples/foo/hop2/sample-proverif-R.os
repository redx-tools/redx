def ginit(bot) {
  new a;
  new a_1;
  new a_2;
  new a_3;
  new a_4;
  new a_5;
  ~M_1 := ocall hinit(bot);
  store L_a[botscope] a;
  store L_a_1[botscope] a_1;
  store L_a_2[botscope] a_2;
  store L_a_3[botscope] a_3;
  store L_a_4[botscope] a_4;
  store L_a_5[botscope] a_5;
  out pair(a, pair(pk(a_1), ~M_1));
}

def AliceAuth(botAauth) {
  load L_a[botscope] a;
  load L_a_2[botscope] a_2;
  load L_a_3[botscope] a_3;
  out blind(commit(vA, a_2), pkS(a), a_3);
}

def BobAuth(botBauth) {
  load L_a[botscope] a;
  load L_a_4[botscope] a_4;
  load L_a_5[botscope] a_5;
  out blind(commit(vB, a_4), pkS(a), a_5);
}

def Alice1(bsA) {
  load L_a_1[botscope] a_1;
  new a_6;
  store L_~M_4[constscope] bsA;
  out enc(dummy, pk(a_1), a_6);
}

def Bob1(bsB) {
  load L_a_1[botscope] a_1;
  new new-name_2;
  out enc(dummy, pk(a_1), new-name_2);
}

def MixnetCollect1Alice(yA) {

  out ok;
}

def MixnetCollect1Bob(yB) {

  out ok;
}

def MixnetCollect1Charlie(y1) {
  store L_~M_8[constscope] y1;
  out ok;
}

def MixnetPublish1(botP) {
  load L_~M_4[constscope] ~M_4;
  load L_~M_8[constscope] ~M_8;
  load L_a[botscope] a;
  load L_a_1[botscope] a_1;
  load L_a_2[botscope] a_2;
  load L_a_3[botscope] a_3;
  load L_a_4[botscope] a_4;
  out shuffle(pair(commit(vA, a_2), unblind(commit(vA, a_2), pkS(a), a_3, ~M_4)), pair(commit(vB, a_4), unblind(commit(vA, a_2), pkS(a), a_3, ~M_4)), dec(~M_8, a_1));
}

def BBset(bb) {
  store L_~M_10[constscope] bb;
  out ok;
}

def Alice2(botAlice2) {
  load L_~M_10[constscope] ~M_10;
  load L_a_2[botscope] a_2;
  ~M_12 := ocall hlor(pair(pair(index(commit(vA, a_2), ~M_10), a_2), dummy));
  out ~M_12;
}

def Bob2(botBob2) {
  load L_~M_10[constscope] ~M_10;
  load L_a_4[botscope] a_4;
  ~M_11 := ocall hlor(pair(pair(index(commit(vB, a_4), ~M_10), a_4), dummy));
  out ~M_11;
}

def MixnetCollect2Alice(zA) {

  out ok;
}

def MixnetCollect2Bob(zB) {

  out ok;
}

def MixnetCollect2Charlie(zC) {
  ~M_18 := ocall hdec(zC);
  store L_~M_18[constscope] ~M_18;
  out ok;
}

def MixnetPublish2(botP2) {
  load L_~M_10[constscope] ~M_10;
  load L_~M_18[constscope] ~M_18;
  load L_a_2[botscope] a_2;
  load L_a_4[botscope] a_4;
  out shuffle(pair(index(commit(vA, a_2), ~M_10), a_2), pair(index(commit(vB, a_4), ~M_10), a_4), ~M_18);
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}