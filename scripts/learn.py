#!/usr/bin/env python3

import json
import os
import difflib
import sys

BASE       = os.path.expanduser("~/.whisp")
RAW_PATH   = os.path.join(BASE, "last_raw.txt")
VOCAB_PATH = os.path.join(BASE, "config", "vocab.json")

if not os.path.exists(RAW_PATH):
    sys.exit(0)

raw       = open(RAW_PATH).read().strip().lower()
corrected = sys.stdin.read().strip().lower()

# nothing to learn if input is empty or identical to the raw transcript
if not corrected or raw == corrected:
    sys.exit(0)

raw_words = raw.split()
cor_words = corrected.split()

matcher = difflib.SequenceMatcher(None, raw_words, cor_words)
pairs   = []

for tag, i1, i2, j1, j2 in matcher.get_opcodes():
    if tag == "replace":
        wrong = " ".join(raw_words[i1:i2])
        right = " ".join(cor_words[j1:j2])
        if wrong and right:
            pairs.append((wrong, right))

vocab = {}
if os.path.exists(VOCAB_PATH):
    with open(VOCAB_PATH) as f:
        vocab = json.load(f)

for wrong, right in pairs:
    vocab[wrong] = right

with open(VOCAB_PATH, "w") as f:
    json.dump(vocab, f, indent=2)
