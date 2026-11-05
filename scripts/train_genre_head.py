#!/usr/bin/env python3
"""Trains a small genre head on CLIP ViT-B/32 embeddings of real book covers.

Covers come from Open Library's public search and covers APIs, by subject. Only embeddings are kept;
no cover image is stored or redistributed. Output: genre-head-vit-b32.json with
  {"model": "ViT-B/32", "genres": [...12 Colophon genre ids...], "weight": [[512]...], "bias": [12],
   "accuracy": held-out accuracy, "samples": per-genre counts}
Logistic regression over unit embeddings; logits = W·e + b.
"""
import argparse, io, json, os, sys, time, urllib.parse, urllib.request

import numpy as np
import torch
from PIL import Image
from transformers import CLIPModel, CLIPProcessor

MODEL = "openai/clip-vit-base-patch32"
# Colophon genre id -> Open Library subject queries (several per genre, pooled).
GENRES = {
    "thriller": ["thriller", "suspense fiction", "spy stories"],
    "mystery": ["mystery fiction", "detective and mystery stories", "crime fiction"],
    "horror": ["horror fiction", "horror tales", "ghost stories"],
    "romance": ["romance fiction", "love stories", "regency romance"],
    "fantasy": ["fantasy fiction", "epic fantasy", "dragons fiction"],
    "scienceFiction": ["science fiction", "space opera", "dystopian fiction"],
    "literary": ["literary fiction", "domestic fiction", "psychological fiction"],
    "historical": ["historical fiction", "world war 1939-1945 fiction", "victorian fiction"],
    "youngAdult": ["young adult fiction", "teenage girls fiction", "coming of age fiction"],
    "cozy": ["cozy mystery", "women sleuths fiction", "cats fiction"],
    "nonfiction": ["self-help", "business", "popular science"],
    "memoir": ["memoir", "autobiography", "biography"],
}
UA = "ColophonCI/1.0 (genre head training; one-off research download)"


def get(url, timeout=30):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def cover_ids(subject, per_query, pages=3):
    ids = []
    for page in range(1, pages + 1):
        q = urllib.parse.urlencode({"subject": subject, "limit": per_query, "page": page, "fields": "cover_i,first_publish_year"})
        try:
            data = json.loads(get(f"https://openlibrary.org/search.json?{q}"))
        except Exception as e:
            print("search failed", subject, page, e)
            break
        for d in data.get("docs", []):
            c = d.get("cover_i")
            y = d.get("first_publish_year") or 0
            if c and y >= 1990:  # modern covers only: the look we want to learn
                ids.append(int(c))
        if len(data.get("docs", [])) < per_query:
            break
        time.sleep(0.4)
    return list(dict.fromkeys(ids))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="build/models")
    ap.add_argument("--per-genre", type=int, default=240)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    model = CLIPModel.from_pretrained(MODEL).eval()
    proc = CLIPProcessor.from_pretrained(MODEL)
    genres = list(GENRES.keys())
    X, y, counts = [], [], {}
    for gi, g in enumerate(genres):
        ids = []
        for subject in GENRES[g]:
            ids += cover_ids(subject, per_query=100)
        ids = list(dict.fromkeys(ids))[: args.per_genre]
        n = 0
        batch = []
        for cid in ids:
            try:
                raw = get(f"https://covers.openlibrary.org/b/id/{cid}-M.jpg", timeout=20)
                if len(raw) < 3000:
                    continue
                img = Image.open(io.BytesIO(raw)).convert("RGB")
                if img.width < 80 or img.height < 100:
                    continue
                batch.append(img)
            except Exception:
                continue
            if len(batch) == 16:
                with torch.no_grad():
                    f = model.get_image_features(**proc(images=batch, return_tensors="pt"))
                    f = f / f.norm(dim=-1, keepdim=True)
                X.extend(f.numpy().tolist()); y.extend([gi] * len(batch)); n += len(batch); batch = []
            time.sleep(0.05)
        if batch:
            with torch.no_grad():
                f = model.get_image_features(**proc(images=batch, return_tensors="pt"))
                f = f / f.norm(dim=-1, keepdim=True)
            X.extend(f.numpy().tolist()); y.extend([gi] * len(batch)); n += len(batch)
        counts[g] = n
        print(g, n, flush=True)

    X = np.array(X, dtype=np.float32); y = np.array(y)
    if len(set(y.tolist())) < 8 or len(y) < 400:
        print("not enough data; skipping head", counts)
        return 0
    from sklearn.linear_model import LogisticRegression
    from sklearn.model_selection import train_test_split
    Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.2, random_state=0, stratify=y)
    clf = LogisticRegression(C=2.0, max_iter=3000, class_weight="balanced")
    clf.fit(Xtr, ytr)
    acc = float(clf.score(Xte, yte))
    clf.fit(X, y)
    present = [genres[i] for i in clf.classes_]
    head = {"model": "ViT-B/32", "genres": present, "weight": clf.coef_.astype(float).tolist(),
            "bias": clf.intercept_.astype(float).tolist(), "accuracy": acc, "samples": counts,
            "source": "Open Library covers by subject (embeddings only; no images kept)"}
    with open(os.path.join(args.out, "genre-head-vit-b32.json"), "w") as f:
        json.dump(head, f)
    print("held-out accuracy", acc, "samples", counts)
    return 0


if __name__ == "__main__":
    sys.exit(main())
