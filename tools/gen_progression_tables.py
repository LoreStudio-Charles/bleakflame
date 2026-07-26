"""Generate the progression tables as CSV — one file per QUALITY grade.

    python tools/gen_progression_tables.py

Writes docs/tables/progression_<grade>.csv, one row per level to MAX_LEVEL.
LEVEL_LOCK marks how far content is balanced today; the curve runs past it so
raising the lock later needs no re-derivation.

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

# The curve's DOMAIN is 60. LEVEL_LOCK is the cap CONTENT is balanced to today and is
# meant to RISE later -- a soft cap that moves, not a design ceiling. Generating the
# full 60 now means raising the lock never requires re-deriving the curve.
MAX_LEVEL = 60
LEVEL_LOCK = 30

# --- the two axes ---------------------------------------------------------
# COMPOUNDING, NOT LINEAR (user, 2026-07-26: "when a player levels they should feel
# it and rejoice"). Linear growth makes every level a SMALLER share of what you
# already have -- at the old 60-cap a level was +5% at the start and +1.3% at the
# end, imperceptible by construction. Compounding is always +8%, so 29->30 feels
# exactly as good as 1->2.
# +8% A LEVEL, ALWAYS, ACROSS ALL 60. Compounding is what makes a level FELT --
# linear growth makes each one a smaller share of what you already have, decaying to
# +1.3% by L60. This is always +8%, so 59->60 lands exactly like 1->2.
#
# It compounds to ~x93 across the domain, and that is DELIBERATE (user: "why can't a
# level 60 be 100 times more powerful than a level 1?"). A spread that large would
# normally wreck grouping -- which is exactly what the LEVEL BANDS below exist to
# solve. Because grouping is gated by BAND rather than by power, the power curve is
# free to be dramatic.
LEVEL_PER_LEVEL = 1.08

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

# --- XP: a level should cost real effort ----------------------------------
# 10x the shipped base of 50 (user: "you shouldn't walk outside, walk back in and
# level up"). Exponent stays at the shipped 1.6 -- with the base already ten times
# higher, steepening the curve as well would put the late game out of reach.
#
# THE REWARDS MUST MOVE TOO, BUT BY LESS. Quests go 50 -> 200 (4x) against a 10x
# cost, which is what actually makes levelling slower rather than just renaming the
# units. Kill XP wants the same treatment -- see the pacing note in
# docs/progression_table.md.
XP_BASE = 500.0
XP_EXP = 1.6

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(REPO, "docs", "tables")
MARKS = ["mk1", "mk2", "mk3", "mk4", "mk5"]


def level_factor(level):
    return LEVEL_PER_LEVEL ** (level - 1)


def xp_for_level(level):
    """Cumulative XP to REACH this level. L1 free.

    Steeper than the shipped 50*(L-1)^1.6 so that halving the level count does not
    halve the career: the total lands within ~1% of the old 60-level total, which
    means each level simply takes about twice as long to earn. That is the "slow
    it down further" half of crunchier levels.
    """
    return int(XP_BASE * pow(float(max(0, level - 1)), XP_EXP))


def group_band(level):
    """The level range this pilot may GROUP with (user, 2026-07-26).

    The band WIDENS as you level, so a big power spread never blocks play:
        L1  -> 1-5      L5  -> 1-10     L10 -> 5-20     L30 -> 15-60

    Below L11 the flat -5 window is the more permissive floor; above it, half-level
    is. `min()` picks whichever is kinder. The top is double, so by L30 the band
    reaches the cap and everyone 30+ groups with everyone 30+.

    THIS IS WHAT MAKES THE x93 CURVE SAFE. Grouping is gated by band, not by power,
    so levels can be dramatic without splitting the playerbase.
    """
    lower = max(1, int(min(level - 5, level / 2.0)))
    upper = min(MAX_LEVEL, max(level * 2, 5))
    return lower, upper


def armor_dr(level, grade_tier, mark):
    """Both axes feed one rating; the rating flattens toward DR_CAP."""
    rating = level + grade_tier * 10 + mark * 5
    return DR_CAP * rating / (rating + DR_K)


def headings():
    cols = ["level", "reachable_now", "level_factor", "xp_total", "xp_this_level",
            "group_min", "group_max"]
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

        lo, hi = group_band(level)
        row = [level, "yes" if level <= LEVEL_LOCK else "no", round(lf, 3),
               xp_for_level(level), xp_for_level(level) - xp_for_level(level - 1),
               lo, hi]
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
        print("  %-46s %d rows x %d cols  (lock %d)" % (
            os.path.relpath(path, REPO), MAX_LEVEL, len(cols), LEVEL_LOCK))
    print("\n%d columns:" % len(cols))
    for c in cols:
        print("   " + c)


if __name__ == "__main__":
    main()
