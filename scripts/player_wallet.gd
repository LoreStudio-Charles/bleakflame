class_name Wallet
## The pilot's credits and experience. Survives scene reloads — death loses your
## cargo, never your banked credits.
##
## A FACADE OVER PlayerState.local (2026-07-27). The data moved so a session can
## hold more than one pilot; the NAME stayed so the 108 sites that read
## Wallet.credits / Wallet.xp did not have to. Read player_state.gd for why the
## migration is shaped this way.

static var credits: int:
	get:
		return PlayerState.local.credits
	set(value):
		PlayerState.local.credits = value

## Pilot experience. Spendable skills arrive with the progression system;
## for now it accumulates so early play still counts later.
static var xp: int:
	get:
		return PlayerState.local.xp
	set(value):
		PlayerState.local.xp = value
