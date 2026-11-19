#!/usr/bin/env python3
"""Slice the Groove MIDI Dataset into a compact bank of real drum grooves and fills.

Source: Groove MIDI Dataset v1.0.0 (midi-only archive), CC BY 4.0
        https://magenta.tensorflow.org/datasets/groove
Usage:  python3 -I scripts/build_groove_bank.py <groove-v1.0.0-midionly.zip> src/engine/data/groove.json

Each groove is four consecutive bars from one performance; each fill is the
fill bar of a short clip. Hits keep their recorded timing (ticks at 480 PPQ
within the bar) and velocity. Voices are folded onto the General MIDI drum map.
"""
import base64, csv, io, json, sys, zipfile, collections

PPQ = 480
BAR = PPQ * 4
EARLY = 64  # hits this many ticks before a bar line belong to the next bar

# Roland TD-11 note -> General MIDI voice
FOLD = {36: 36, 38: 38, 40: 38, 37: 37, 48: 50, 50: 50, 45: 47, 47: 47, 43: 43, 58: 43,
        46: 46, 26: 46, 42: 42, 22: 42, 44: 44, 49: 49, 55: 49, 57: 57, 52: 57, 51: 51, 59: 51, 53: 53}
VOICES = [36, 38, 37, 42, 44, 46, 51, 53, 49, 57, 50, 47, 43]
VIDX = {v: i for i, v in enumerate(VOICES)}
CAP = {'rock': 110, 'funk': 90, 'jazz': 80, 'latin': 70, 'hiphop': 60, 'soul': 60, 'neworleans': 40, 'pop': 40}
DEFAULT_CAP = 40


def parse(data):
    """Return (ppq, [(tick, note, vel)]) for note-ons."""
    pos = 0
    def u32():
        nonlocal pos
        v = int.from_bytes(data[pos:pos + 4], 'big'); pos += 4; return v
    def u16():
        nonlocal pos
        v = int.from_bytes(data[pos:pos + 2], 'big'); pos += 2; return v
    assert data[:4] == b'MThd'; pos = 4
    hlen = u32(); u16(); ntr = u16(); ppq = u16(); pos = 8 + hlen
    notes = []
    for _ in range(ntr):
        assert data[pos:pos + 4] == b'MTrk'; pos += 4
        end = pos + u32()
        t = 0; status = 0
        while pos < end:
            v = 0
            while True:
                b = data[pos]; pos += 1
                v = (v << 7) | (b & 0x7F)
                if not b & 0x80: break
            t += v
            b = data[pos]
            if b & 0x80:
                pos += 1
                if b < 0xF0: status = b
            else:
                b = status
            if b == 0xFF:
                pos += 1
                ln = 0
                while True:
                    c = data[pos]; pos += 1
                    ln = (ln << 7) | (c & 0x7F)
                    if not c & 0x80: break
                pos += ln
            elif b in (0xF0, 0xF7):
                ln = 0
                while True:
                    c = data[pos]; pos += 1
                    ln = (ln << 7) | (c & 0x7F)
                    if not c & 0x80: break
                pos += ln
            else:
                kind = b & 0xF0
                d1 = data[pos]; pos += 1
                d2 = 0
                if kind not in (0xC0, 0xD0):
                    d2 = data[pos]; pos += 1
                if kind == 0x90 and d2 > 0:
                    notes.append((t, d1, d2))
        pos = end
    return ppq, notes


def pack(bars):
    out = bytearray()
    for hits in bars:
        out += len(hits).to_bytes(1, 'big')
        for p, v, vel in hits:
            q = p + EARLY  # 0..2047
            out += bytes([q >> 3, ((q & 7) << 5) | (v << 1) | (vel >> 6), (vel & 63) << 2])
    return base64.b64encode(bytes(out)).decode()


def swing_of(bars, unit):
    """Mean lateness of the off-beat subdivision, 0 = straight, 1 = triplet."""
    half = unit // 2
    xs = []
    for hits in bars:
        for p, v, vel in hits:
            if VOICES[v] not in (42, 46, 51): continue
            x = p % unit
            # the off-beat lands between "straight" (half) and "triplet" (two thirds); the next
            # finer subdivision at three quarters must stay out of the window
            if half * 0.8 <= x <= half * 1.43: xs.append(x)
    if len(xs) < 8: return None
    m = sum(xs) / len(xs)
    return max(0.0, min(1.0, (m - half) / (unit / 6)))


def main(src, dst):
    z = zipfile.ZipFile(src)
    info = [n for n in z.namelist() if n.endswith('info.csv')][0]
    rows = [r for r in csv.DictReader(io.StringIO(z.read(info).decode())) if r['time_signature'] == '4-4']
    root = info.rsplit('/', 1)[0]
    grooves, fills = [], []
    per_style = collections.Counter()
    rows.sort(key=lambda r: (r['style'], -float(r['duration'])))
    for fi, r in enumerate(rows):
        style = r['style'].split('/')[0]
        try:
            ppq, notes = parse(z.read(root + '/' + r['midi_filename']))
        except Exception as e:  # unreadable file: skip
            continue
        scale = PPQ / ppq
        bars = collections.defaultdict(list)
        for t, n, vel in notes:
            if n not in FOLD: continue
            tt = int(round(t * scale))
            b = (tt + EARLY) // BAR
            bars[b].append((tt - b * BAR, VIDX[FOLD[n]], vel))
        if not bars: continue
        nb = max(bars) + 1
        seq = [sorted(set(bars.get(i, [])))[:120] for i in range(nb)]
        drummer = int(r['drummer'].replace('drummer', ''))
        bpm = int(r['bpm'])
        if r['beat_type'] == 'fill':
            # the busiest bar of the clip is the fill itself
            best = max(range(nb), key=lambda i: len(seq[i]))
            if len(seq[best]) < 4: continue
            w8, w16 = swing_of([seq[best]], PPQ), swing_of([seq[best]], PPQ // 2)
            fills.append({'s': style, 'b': bpm, 'd': drummer, 'n': len(seq[best]), 'h': pack([seq[best]])})
            continue
        ok = lambda i: 6 <= len(seq[i]) <= 110 and any(VOICES[v] == 36 for _, v, _ in seq[i])
        chunks = [i for i in range(0, nb - 3, 4) if all(ok(j) for j in range(i, i + 4))]
        if not chunks: continue
        cap = CAP.get(style, DEFAULT_CAP)
        want = 3 if len(chunks) >= 6 else 2 if len(chunks) >= 3 else 1
        picks = [chunks[0], chunks[len(chunks) // 2], chunks[-1]][:want] if want > 1 else [chunks[len(chunks) // 2]]
        for ci in dict.fromkeys(picks):
            if per_style[style] >= cap: break
            four = seq[ci:ci + 4]
            w8, w16 = swing_of(four, PPQ), swing_of(four, PPQ // 2)
            grooves.append({'s': style, 'b': bpm, 'd': drummer, 'f': fi,
                            'n': round(sum(len(x) for x in four) / 4),
                            'w8': -1 if w8 is None else round(w8 * 100), 'w16': -1 if w16 is None else round(w16 * 100),
                            'h': pack(four)})
            per_style[style] += 1
    out = {
        'source': 'Groove MIDI Dataset v1.0.0 (Gillick, Roberts, Engel, Eck, Bamman, 2019), CC BY 4.0, https://magenta.tensorflow.org/datasets/groove. Sliced into bars and re-encoded.',
        'voices': VOICES, 'early': EARLY, 'grooves': grooves, 'fills': fills,
    }
    with open(dst, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    gs = collections.Counter(g['s'] for g in grooves); fs = collections.Counter(x['s'] for x in fills)
    print('grooves', len(grooves), 'x4 bars =', len(grooves) * 4, dict(gs))
    print('fills', len(fills), dict(fs))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
