extends RefCounted
## A three-reel slot machine. Each reel stops on a symbol picked by weight, and the
## reels are independent: the outcome is honest, whatever the animation suggests.
## Machines near the door are "loose" (they pay back more), a real casino tactic.

const SYMBOLS := ["7", "BAR", "★", "♦", "♥", "●"]  # the last one is the cherry
const CHERRY := 5
## Payout for three of a kind, as a multiple of the bet.
const TRIPLE := [200, 60, 30, 15, 8, 5]
const TIGHT := [3, 5, 6, 7, 9, 5]
const LOOSE := [1, 2, 3, 4, 5, 10]


static func spin(rng: RandomNumberGenerator, loose: bool) -> Array[int]:
	var weights := PackedFloat32Array(LOOSE if loose else TIGHT)
	var out: Array[int] = []
	for i in 3:
		out.append(rng.rand_weighted(weights))
	return out


## What a result pays, as a multiple of the bet. Cherries on the first reel pay small.
static func payout(reels: Array) -> int:
	if reels[0] == reels[1] and reels[1] == reels[2]:
		return TRIPLE[reels[0]]
	if reels[0] == CHERRY:
		return 2 if reels[1] == CHERRY else 1
	return 0


## The exact share of money bet that the machine pays back over time.
static func rtp(loose: bool) -> float:
	var w: Array = LOOSE if loose else TIGHT
	var sum := 0.0
	for x in w:
		sum += x
	var total := 0.0
	for a in 6:
		for b in 6:
			for c in 6:
				total += payout([a, b, c]) * (w[a] / sum) * (w[b] / sum) * (w[c] / sum)
	return total
