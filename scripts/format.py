#!/usr/bin/env python3

import sys
import json
import re
import os
import subprocess

from rapidfuzz import fuzz

BASE       = os.path.expanduser("~/.whisp")
VOCAB_PATH = os.path.join(BASE, "config", "vocab.json")

text = sys.stdin.read().strip().lower()

# ── phonetic corrections ──────────────────────────────────────────────────────
# Maps the correct term to a list of common mishearings from Whisper.

phonetic = {
    "kubectl": [
        "cube cuddle", "cube cuttle", "cube control",
        "kube cuddle", "kube control", "kubernetes control",
    ],
    "terraform": ["terra form", "terra from"],
    "golang":    ["go lang"],
    "prometheus": ["promethius"],
    "grafana":   ["grafanna"],
}

for target, variants in phonetic.items():
    for variant in variants:
        if fuzz.partial_ratio(variant, text) > 85:
            text = re.sub(r'\b' + re.escape(variant) + r'\b', target, text)

# ── learned vocabulary corrections ───────────────────────────────────────────

if os.path.exists(VOCAB_PATH):
    with open(VOCAB_PATH) as f:
        vocab = json.load(f)
    # apply longest matches first to avoid partial replacements
    for wrong, correct in sorted(vocab.items(), key=lambda x: -len(x[0])):
        text = re.sub(r'\b' + re.escape(wrong) + r'\b', correct, text)

# ── punctuation ───────────────────────────────────────────────────────────────

punct = {
    "comma":            ",",
    "period":           ".",
    "question mark":    "?",
    "exclamation mark": "!",
    "colon":            ":",
    "semicolon":        ";",
}

for k, v in punct.items():
    text = re.sub(r'\b' + re.escape(k) + r'\b', v, text)

# ── code symbols ──────────────────────────────────────────────────────────────

symbols = {
    "open brace":           "{",
    "close brace":          "}",
    "open bracket":         "(",
    "close bracket":        ")",
    "open square bracket":  "[",
    "close square bracket": "]",
    "dot":                  ".",
    "equals":               "=",
    "arrow":                "->",
}

for k, v in symbols.items():
    text = re.sub(r'\b' + re.escape(k) + r'\b', v, text)

# ── kubectl shorthand aliases ─────────────────────────────────────────────────

aliases = {
    r"\bk get\b":      "kubectl get",
    r"\bk describe\b": "kubectl describe",
    r"\bk logs\b":     "kubectl logs",
    r"\bk apply\b":    "kubectl apply",
    r"\bk delete\b":   "kubectl delete",
    r"\bk exec\b":     "kubectl exec",
}

for pattern, repl in aliases.items():
    text = re.sub(pattern, repl, text)

# ── case helpers ──────────────────────────────────────────────────────────────

def snake_case(words):
    return "_".join(words)

def camel_case(words):
    return words[0] + "".join(w.capitalize() for w in words[1:])

text = re.sub(
    r'snake ([a-z0-9 ]+)',
    lambda m: snake_case(m.group(1).split()),
    text,
)
text = re.sub(
    r'camel ([a-z0-9 ]+)',
    lambda m: camel_case(m.group(1).split()),
    text,
)

# ── markdown code block ───────────────────────────────────────────────────────

text = re.sub(
    r'code block(\s+\w+)?',
    lambda m: "```{}\n\n```".format(m.group(1).strip() if m.group(1) else ""),
    text,
)

# ── app-aware formatting ──────────────────────────────────────────────────────

try:
    app = subprocess.check_output(
        ["osascript", "-e",
         'tell application "System Events" to get name of first application process whose frontmost is true'],
        stderr=subprocess.DEVNULL,
    ).decode().strip()
except Exception:
    app = ""

CHAT_APPS = {"Slack", "Discord", "Telegram", "WhatsApp"}
MAIL_APPS = {"Mail", "Spark"}

if app in MAIL_APPS:
    if text and not text.endswith("."):
        text += "."

if app in CHAT_APPS | MAIL_APPS:
    if text:
        text = text[0].upper() + text[1:]

# ── final cleanup ─────────────────────────────────────────────────────────────

text = re.sub(r'\s+', ' ', text).strip()

print(text)
