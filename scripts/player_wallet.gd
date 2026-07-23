class_name Wallet
## Session-persistent credits. Static so it survives scene reloads (death
## loses your cargo, never your banked credits). Real persistence comes with
## save games.

static var credits := 0
## Pilot experience. Spendable skills arrive with the progression system;
## for now it accumulates so early play still counts later.
static var xp := 0
