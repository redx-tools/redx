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
  out pair(a, pair(~M_1, pk(a_1)));
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
  load L_a[botscope] a;
  load L_a_2[botscope] a_2;
  load L_a_3[botscope] a_3;
  ~M_5 := ocall hlor(pair(pair(commit(vA, a_2), unblind(commit(vA, a_2), pkS(a), a_3, bsA)), dummy));
  store L_~M_4[constscope] bsA;
  out ~M_5;
}

def Bob1(bsB) {
  load L_a[botscope] a;
  load L_a_4[botscope] a_4;
  load L_a_5[botscope] a_5;
  ~M_7 := ocall hlor(pair(pair(commit(vB, a_4), unblind(commit(vB, a_4), pkS(a), a_5, bsB)), dummy));
  out ~M_7;
}

def MixnetCollect1Alice(yA) {

  out ok;
}

def MixnetCollect1Bob(yB) {

  out ok;
}

def MixnetCollect1Charlie(y1) {
  ~M_11 := ocall hdec(y1);
  store L_~M_11[constscope] ~M_11;
  out ok;
}

def MixnetPublish1(botP) {
  load L_~M_4[constscope] ~M_4;
  load L_~M_11[constscope] ~M_11;
  load L_a[botscope] a;
  load L_a_2[botscope] a_2;
  load L_a_3[botscope] a_3;
  load L_a_4[botscope] a_4;
  out shuffle(pair(commit(vA, a_2), unblind(commit(vA, a_2), pkS(a), a_3, ~M_4)), pair(commit(vB, a_4), unblind(commit(vA, a_2), pkS(a), a_3, ~M_4)), ~M_11);
}

def BBset(bb) {
  store L_~M_13[constscope] bb;
  out ok;
}

def Alice2(botAlice2) {
  load L_~M_13[constscope] ~M_13;
  load L_a_1[botscope] a_1;
  load L_a_2[botscope] a_2;
  new a_9;
  out enc(pair(index(commit(vA, a_2), ~M_13), a_2), pk(a_1), a_9);
}

def Bob2(botBob2) {
  load L_~M_13[constscope] ~M_13;
  load L_a_1[botscope] a_1;
  load L_a_4[botscope] a_4;
  new new-name_2;
  out enc(pair(index(commit(vB, a_4), ~M_13), a_4), pk(a_1), new-name_2);
}

def MixnetCollect2Alice(zA) {

  out ok;
}

def MixnetCollect2Bob(zB) {

  out ok;
}

def MixnetCollect2Charlie(zC) {
  store L_~M_18[constscope] zC;
  out ok;
}

def MixnetPublish2(botP2) {
  load L_~M_13[constscope] ~M_13;
  load L_~M_18[constscope] ~M_18;
  load L_a_1[botscope] a_1;
  load L_a_2[botscope] a_2;
  load L_a_4[botscope] a_4;
  out shuffle(pair(index(commit(vA, a_2), ~M_13), a_2), pair(index(commit(vB, a_4), ~M_13), a_4), dec(~M_18, a_1));
}

def gfin(guess) {
  _ := ocall hfin(guess);
  out bot;
}