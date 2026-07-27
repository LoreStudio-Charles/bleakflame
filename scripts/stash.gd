class_name Stash
## Station component storage. SAFE — the hold flies with you and dies with you;
## the stash stays at the station. Unlimited for now; when multiple stations exist
## we decide whether storage is shared or per-station.
##
## A FACADE OVER PlayerState.local (2026-07-27). The data moved so a session can
## hold more than one pilot; the NAME stayed so the 29 sites that read
## Stash.items / Stash.commodities did not have to. Read player_state.gd for why
## the migration is shaped this way.
##
## The getters hand back the pilot's own arrays BY REFERENCE, so the existing
## `Stash.items.append(...)` / `.assign(...)` / `.clear()` idioms all still write
## through to the right pilot.

static var items: Array[ComponentDef]:
	get:
		return PlayerState.local.stash_items
	set(value):
		PlayerState.local.stash_items = value

## Materials (mined ore, etc.) kept SAFE at the station — the same promise as
## `items`, for the commodities the hold would otherwise lose on death. key->qty.
static var commodities: Dictionary:
	get:
		return PlayerState.local.stash_commodities
	set(value):
		PlayerState.local.stash_commodities = value


static func store_commodity(key: String, qty: int) -> void:
	if qty > 0:
		commodities[key] = int(commodities.get(key, 0)) + qty


## Withdraw up to `qty`; returns how many actually came out of the stash.
static func take_commodity(key: String, qty: int) -> int:
	var n := mini(int(commodities.get(key, 0)), maxi(0, qty))
	if n > 0:
		commodities[key] = int(commodities[key]) - n
		if commodities[key] <= 0:
			commodities.erase(key)
	return n
