"""Generate the progression tables as CSV — one file per QUALITY grade.

    python tools/gen_progression_tables.py

Writes docs/tables/progression_<grade>.csv, 60 rows (one per level) each.

WHY A GENERATOR AND NOT HAND-MAINTAINED FILES: every number here comes from the
handful of constants at the top. Tune one, re-run, and all seven files move
together. Hand-edited tables drift from each other the moment anyone rebalances,
and a table that disagrees with its neighbours is worse than no table.

The curves are documented in docs/progression_table.md, which explains WHY each
one has the shape it does. This file is the arithmetic; that file is the
reasoning. Read that one first.

Anchors (so the tables describe the game that exists rather than replacing it):
  Rooster 110 hull . Bulwark Plating 80 armor . Veil Shield 60 hp / 4.0 regen
  VK-2 Autocannon 5 damage / 0.25s = 20 dps
All bases below are STANDARD-grade numbers, because Standard is the 1.00 anchor.
"""
import csv
import os

MAX_LEVEL = 60

# --- the two axes ---------------------------------------------------------
LEVEL_PER = 0.05          # level_factor = 1 + (L-1) * this  -> L60 = 3.95x

GRADES = [                # name, factor, tier index (feeds the DR rating)
    ("flotsam",      0.80, 0),
    ("salvage",      0.90, 1),
    ("standard",     1.00, 2),
    ("advanced",     1.15, 3),
    ("experimental", 1.32, 4),
    ("bespoke",      1.52, 5),
    ("exotic",       1.75, 6),
]

# --- bases at L1, STANDARD ------------------------------------------------
HULL_BAND = {             # doubles per band, matching the art-canvas budget
    "light": 120, "medium": 260, "heavy": 560,
    "super_heavy": 1200, "super_heavy_plus": 2600,
}
SHIELD_HP = [60, 110, 190, 320, 520]        # by mark I..V
SHIELD_REGEN = [4.0, 5.4, 7.2, 9.6, 12.8]
ARMOR_HP = [80, 145, 250, 420, 680]
WEAPON_DPS = [20, 34, 58, 98, 166]

# Sub-linear exponents. Regen must NOT keep pace with the shield pool, or a
# high-tier shield refills during any lull and armor/hull stop mattering --
# SHIELD_REGEN_DELAY is a fixed 2.5s that does not scale.
REGEN_EXP = 0.5
DOT_SCALE = 0.60          # recurring damage trades immediacy for total
DOT_EXP = 0.80            # ...and scales more slowly too

# --- armor DR: both axes through a flattening curve to a HARD cap ---------
# DR multiplies the pool, so it can never be a straight multiplier or armor
# outgrows every other layer. Marine affinity raises DR_CAP, never the rating.
DR_CAP = 0.40
DR_K = 40.0

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(REPO, "docs", "tables")
MARKS = ["mk1", "mk2", "mk3", "mk4", "mk5"]


def level_factor(level):
    return 1.0 + (level - 1) * LEVEL_PER


def armor_dr(level, grade_tier, mark):
    """Both axes feed one rating; the rating flattens toward DR_CAP."""
    rating = level + grade_tier * 10 + mark * 5
    return DR_CAP * rating / (rating + DR_K)


def headings():
    cols = ["level", "level_factor"]
    cols += ["hull_" + b for b in HULL_BAND]
    for prefix in ("shield_hp", "shield_regen", "armor_hp", "armor_dr", "dps", "dot_dps"):
        cols += ["%s_%s" % (prefix, m) for m in MARKS]
    return cols


def rows_for(grade_factor, grade_tier):
    for level in range(1, MAX_LEVEL + 1):
        lf = level_factor(level)
        pool = lf * grade_factor                       # pools take both axes flat
        regen = (lf ** REGEN_EXP) * (grade_factor ** REGEN_EXP)
        dot = (lf ** DOT_EXP) * (grade_factor ** DOT_EXP) * DOT_SCALE

        row = [level, round(lf, 3)]
        row += [round(HULL_BAND[b] * pool) for b in HULL_BAND]
        row += [round(v * pool) for v in SHIELD_HP]
        row += [round(v * regen, 2) for v in SHIELD_REGEN]
        row += [round(v * pool) for v in ARMOR_HP]
        row += [round(armor_dr(level, grade_tier, m) * 100, 1) for m in range(1, 6)]
        row += [round(v * pool, 1) for v in WEAPON_DPS]
        row += [round(v * dot, 1) for v in WEAPON_DPS]
        yield row


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    cols = headings()
    for name, factor, tier in GRADES:
        path = os.path.join(OUT_DIR, "progression_%s.csv" % name)
        with open(path, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(cols)
            for row in rows_for(factor, tier):
                w.writerow(row)
        print("  %-46s %d rows x %d cols" % (
            os.path.relpath(path, REPO), MAX_LEVEL, len(cols)))
    print("\n%d columns:" % len(cols))
    for c in cols:
        print("   " + c)


if __name__ == "__main__":
    main()
