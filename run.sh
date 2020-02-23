#!/usr/bin/env bash

# Description: This file is used to generate a chinese HCLG example
#
# Author: Xiangyu Ju
# Date: 2020/02/23

echo "kaldi root = ${KALDI_ROOT}"

if [ ! -L utils ]; then
  ln -s ${KALDI_ROOT}/egs/wsj/s5/utils utils && echo "create link to kaldi/egs/wsj/s5/utils"
fi
# create fst directory to store generated fst file
if [ ! -d "fst" ]; then
  mkdir "fst" && echo "[Info]: create fst directory to store fst files"
fi

# use srilm to generate arpa
ngram-count -text data/lm/train.txt -order 3 -write data/lm/3-gram.count \
|| { echo "[Error]: Find error when calling ngram-count" && exit 1;}
ngram-count -read data/lm/3-gram.count -order 3 -lm data/lm/3-gram.arpa \
|| { echo "[Error]: Find error when calling ngram-count" && exit 1;}
echo "[Info]: finishing generating arpa file"

# create lang first to generate words.txt as the input of arpa2fst
utils/prepare_lang.sh --position-dependent-phones false data/dict "<UNK>" data/tmp data/lang \
|| { echo "[Error]: Find error when executing utils/prepare_lang.sh" && exit 1;}
echo "[Info]: finishing generating arpa file"

# copy L_disambig.fst to fst/
cp data/lang/L_disambig.fst fst/L.fst || { echo "[Error]: data/lang/L_disambig.fst is not existed" && exit 1;}
echo "[Info]: copy L_disambig.fst to fst/L.fst"

# build G.fst using arpa2fst
arpa2fst --disambig-symbol=\#0 --read-symbol-table=data/lang/words.txt data/lm/3-gram.arpa fst/G.fst \
|| { echo "[Error]: Find error when calling arpa2fst" && exit 1;}
echo "[Info]: finish generating G.fst"

# compose LG
fstcompose fst/L.fst fst/G.fst fst/LG.fst || exit 1
echo "[Info]: LG composition is done"
# determinize
fstdeterminize fst/LG.fst > fst/det-LG.fst || exit 1
echo "[Info]: LG determinization is done"
# minimization
fstminimize fst/det-LG.fst fst/min-det-LG.fst || exit 1
echo "[Info]: LG minimization is done"

# create directory to store C.fst output
if [ ! -d "data/context_phone" ]; then
  mkdir "data/context_phone" && echo "[Info]: create data/context_phone directory to store CLG.fst output"
fi

# compose CLG. We use monophone as a example, so this C.fst is a simple mapping from monophone to itself.
# Kaldi does not create a real C.fst.
# It finds all existed context phone in min-det-LG.fst and only use these phones to do composition
fstcomposecontext --central-position=0 \
                  --context-size=1 \
                  --read-disambig-syms=data/lang/phones/disambig.int \
                  --write-disambig-syms=data/context_phone/disambig_ilabels.int \
                  data/context_phone/c_ilabels < fst/min-det-LG.fst > fst/CLG.fst  \
                  || { echo "[Error]: Find error when calling fstcomposecontext" && exit 1;}
echo "[Info]: finish generating CLG.fst"
fstmakecontextsyms  data/lang/phones.txt data/context_phone/c_ilabels > data/context_phone/context_symbols.txt
echo "[Info]: generate CLG input symbol at data/context_phone/context_symbols.txt"


# determinize
fstdeterminize fst/CLG.fst > fst/det-CLG.fst || exit 1
# minimization
fstminimize fst/det-CLG.fst fst/min-det-CLG.fst || exit 1
echo "[Info]: CLG determinization & minimization is done"

# create directory to store gmm model
if [ ! -d "data/gmm" ]; then
  mkdir "data/gmm" && echo "[Info]: create data/gmm directory to store gmm model"
fi

# create gmm model,
gmm_dim=40
gmm-init-mono data/lang/topo ${gmm_dim} data/gmm/gmm.mdl data/gmm/phone.tree \
|| { echo "[Error]: Find error when calling gmm-init-mono" && exit 1;}
echo "[Info]: create gmm monophone model"
make-h-transducer --disambig-syms-out=data/gmm/disambig_tid.int data/context_phone/c_ilabels data/gmm/phone.tree data/gmm/gmm.mdl > fst/Ha.fst \
|| { echo "[Error]: Find error when calling make-h-transducer" && exit 1;}
echo "[Info]: create acyclic hmm fst graph - Ha.fst"
# create H.fst
fstrmsymbols data/gmm/disambig_tid.int fst/Ha.fst > fst/rds-Ha.fst || exit 1
add-self-loops data/gmm/gmm.mdl fst/rds-Ha.fst fst/H.fst || { echo "[Error]: Find error when calling add-self-loop" && exit 1;}
echo "[Info]: create normal hmm fst graph - H.fst"
# compose HaCLG
fstcompose fst/Ha.fst fst/min-det-CLG.fst fst/HaCLG.fst || exit 1
# determinize
fstdeterminize fst/HaCLG.fst > fst/det-HaCLG.fst || exit 1
echo "[Info]: det-rds-HaCLG.fst is done"
# minimization
fstminimize fst/det-HaCLG.fst fst/min-det-HaCLG.fst || exit 1
echo "[Info]: min-det-rds-HaCLG.fst is done"
# remove disambig symbols
fstrmsymbols data/gmm/disambig_tid.int fst/min-det-HaCLG.fst > fst/rds-min-det-HaCLG.fst || exit 1
echo "[Info]: remove disambig symbols of the final graph"
# add self loop for hmm
add-self-loops data/gmm/gmm.mdl fst/rds-min-det-HaCLG.fst fst/HCLG.fst \
|| { echo "[Error]: Find error when calling add-add-self-loops" && exit 1;}
echo "[Info]: add self loop for hmm"
echo "[Info]: finish generating HCLG graph"

# print fst graph
if [ ! -d "graph" ]; then
  mkdir "graph" && echo "[Info]: create graph directory to store fst jpg files"
fi

# convert fst to dot
fstdraw --isymbols=data/lang/words.txt --osymbols=data/lang/words.txt fst/G.fst > graph/G.dot
fstdraw --isymbols=data/lang/phones.txt --osymbols=data/lang/words.txt fst/L.fst > graph/L.dot
fstdraw --osymbols=data/context_phone/context_symbols.txt fst/H.fst > graph/H.dot

# Default jpg size might be very small, change the size for clear pics
sed -i 's/size = \"8.5,11\"/size = \"25,40\"/g' graph/G.dot
sed -i 's/size = \"8.5,11\"/size = \"25,40\"/g' graph/L.dot
sed -i 's/size = \"8.5,11\"/size = \"25,40\"/g' graph/H.dot

dot -Tjpg graph/G.dot > graph//G.jpg
dot -Tjpg graph/L.dot > graph//L.jpg
dot -Tjpg graph/H.dot > graph//H.jpg


