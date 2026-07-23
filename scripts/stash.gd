class_name Stash
## Station component storage. Session-persistent (static, like the Wallet) and
## SAFE — the hold flies with you and dies with you; the stash stays at the
## station. Unlimited for now; when multiple stations exist we decide whether
## storage is shared or per-station.

static var items: Array[ComponentDef] = []
## Materials (mined ore, etc.) kept SAFE at the station — the same promise as
## `items`, for the commodities the hold would otherwise lose on death. key->qty.
static var commodities: Dictionary = {}


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
