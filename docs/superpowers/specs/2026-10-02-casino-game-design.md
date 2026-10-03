# Casino Game — Design

Date: 2026-10-02. Working title: "casino game" (no real name chosen yet).

## What it is

A first-person story game set inside a corrupt casino. You work there, you
owe a debt, and security is slowly closing in. You get money by gambling, by
doing what the casino orders, or by stealing from it. The look and feel take
after Schedule I: stylized people in a grounded world you walk around in.

## Fixed constraints

- Godot 4.7.1, Forward+ renderer, GDScript. Mac app first.
- Play money only. No purchases, no cash-out, no accounts, no real-money links.
- No login-streak or guilt-based hooks. Casino-style juice (near-misses,
  variable rewards, sound and light) is allowed inside the game, and the story
  reveals how those tricks work.
- Single player. Multiplayer is a later goal and is not designed here.

## Story

You are a new employee at a casino that is rigged and launders money. You owe
a loan shark. Each night you work a shift, and on your own time you can gamble.

Storylines are long threads, each many nights long, with their own characters
and their own clock:

- Pay the debt (the loan shark).
- Work for the casino (rig games, earn standing).
- Help an investigator (gather evidence).
- Rob the vault (steal big and escape).

Your decisions open and close threads. You are not locked into one: you can
drop a thread midway and take another, and the people you leave remember it.
Endings come from which threads you finished, abandoned or betrayed.

Held in reserve: a "corruption" measure that changes dialogue and offers as
you win and steal more.

Opening mission: the manager orders you to make a particular customer lose at
blackjack. During the shift you learn that the customer is paying off a debt
like yours. You can follow the order, warn them, or use the moment to take
evidence.

## Nights

Nights must not feel the same. Each night is assembled from:

- Your station (blackjack table, cage, floor).
- One or more events (VIP arrives, audit, power flicker, a regular asks a favor).
- Which staff and guards are on duty, on schedules that change through the night.

There is no single global deadline. Each thread has its own clock, and clocks
can appear, move or vanish because of your choices.

## Core systems

| System | What it does |
|---|---|
| Bankroll | Your play money. |
| Debt | What you owe, with the loan shark's payment schedule. |
| Heat | One number for security's attention. Cheating, winning a lot, entering staff areas and talking to the wrong people raise it. It decays slowly. |
| Story state | Flags, relationships, heat, debt and the list of active threads. |
| Threads | Data files of story beats, each with conditions on the story state. |
| Night generator | Picks station, events and staff from the story state. |
| Phone | Texts from the loan shark and others deliver threats and orders. |
| House tricks | Real casino tactics placed in the world for you to spot (loose slots near the door, no clocks, free drinks). |

Getting caught has consequences, not a reset: you lose items, access or
standing, and the story branches. A full game over happens only at an ending.

## Gambling games

Eventually: blackjack, slots, dice (craps), roulette, Plinko, Mines, and an
in-game laptop with sketchy online casino sites (crash games and the like).

Blackjack is real blackjack with honest odds, plus tricks you unlock through
the story: peeking, card counting, marked cards, stacking the deck. Using a
trick raises heat. You play it from both sides — as the dealer on shift and as
a player on your own time.

Between sessions you walk the casino, talk to people, take missions, buy tools
and perks, and unlock higher-stakes rooms.

## Look

- Public floor: neon Vegas night. Magenta and cyan light, dark wood and brass,
  wet reflective floors, haze, glowing slot banks, visible security cameras.
- Higher-stakes rooms: classic green felt and warm brass, quiet and exposed.
- Surroundings lean realistic: PBR materials, global illumination, screen-space
  reflections, volumetric fog, glow, depth of field.
- People are Schedule I-style: stylized and simplified, no photoreal faces.
- The reference concept image is a mood target, not a quality target. The game
  will not look like a photograph.

## Architecture

Game rules live in plain GDScript classes with no scene dependencies, so they
can be tested headless. Scenes only display state and send input.

- `logic/` — blackjack rules, deck, heat, story state, thread loading, night
  generator. Pure code, covered by tests.
- `world/` — the casino room, props, lighting, environment.
- `player/` — first-person controller and interaction ray.
- `tables/` — the blackjack table scene, which drives `logic/` and shows cards
  and chips.
- `npc/` — characters and dialogue.
- `ui/` — HUD (bankroll, debt, heat), dialogue box, phone.
- `data/` — thread and event definitions.
- `tests/` — a headless test runner script, run with
  `godot --headless --script`.

Random numbers come from a seedable generator passed into the logic, so tests
are repeatable.

## Milestone 1

One playable slice that proves the feel:

- One neon casino room you walk around in first person (WASD, mouse look,
  E to interact).
- One blackjack table. Player side: bet, hit, stand, double. Dealer side for
  the opening mission, with one cheat action (stack the next card) that raises
  heat.
- Rules: six decks, dealer stands on all 17s, blackjack pays 3:2, no splitting
  and no insurance yet.
- HUD with bankroll, debt and heat.
- The manager NPC, stylized, who gives the opening mission through a simple
  dialogue box.
- The opening mission with its three outcomes, each recorded in the story state.
- The story-state and thread framework, with this one short thread as data.
- Lighting and post-processing to set the mood. Basic sound and feedback on
  deals, wins and losses.
- Tests for blackjack scoring and payouts, heat, and thread conditions.

Not in milestone 1: other games, the night generator, the phone, staff
schedules, upgrades and the shop, VIP rooms, the laptop, saving, more threads,
multiplayer, and downloaded art packs.

## Testing and review

- Logic tests run headless and must pass before each step is called done.
- A simulated run of many blackjack hands checks that the house edge lands near
  the expected value for these rules.
- Visuals are judged from screenshots of the running game.
- Feel can only be judged by the player: each build goes to Alexander to try.

## Risks

- Scope. Long branching storylines are the largest cost, mostly in writing and
  scenes. Build systems first, then add one thread at a time.
- Characters. Animated people are hard to author from code. Milestone 1 uses
  simple stylized figures with little or no animation.
- Realism. Lighting carries the look. Without art assets the props stay simple.

## Milestone 2 (built 2026-10-03)

- Saving to `user://save.json`, written whenever you are back in control.
- The night loop: leave by the exit doors to end a night. Heat halves, clocks
  move, the next night is planned and the scene reloads.
- Night plans (`logic/night.gd`): a customer, an order from Halloran (none, lose,
  win, straight) and an event (quiet, audit, bad wiring, high roller, promo). A
  story thread can force parts of the plan through a job.
- Wage of $150 per shift, plus a reward or penalty judged against the order.
- Sal: installments with deadlines that vary, paid from the phone. A missed
  payment costs half your cash and a penalty; three misses end the run. Clearing
  the debt is the first good ending. Loans: $500 for $750 of debt.
- Phone (Tab): texts, what Sal wants, pay and borrow.
- Threads: `floor` (always on), `house` (Halloran's laundering job, ends with the
  gold card) and `inspector` (Ines Park; you can sell her out to Halloran).
- Slots (`logic/slots.gd`): three honest reels. Tight machines pay back 88%, loose
  ones by the doors 97%. A regular tells you the trick, after which machines are
  labelled.

Still not built: VIP room, tools and perks, staff schedules, the vault thread,
more games, the laptop.
