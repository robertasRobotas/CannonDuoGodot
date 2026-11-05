## The story of Chapter 1. You are the young gunner of the last navy ship afloat; the Captain
## gives the orders. Scenes play once before or after a level; Pip jokes after the other wins.
## Lines are kept short: one thought each, never a paragraph.
class_name Story

## "N_before" plays before level N starts, "N_after" after it is won. Each line: [who, text].
## The 3_before scene is overheard through the cabin door (the eavesdrop presentation).
const BEATS := {
    "1_before": [
        ["king", "Grimhorn stole my islands, my people and my good spoons."],
        ["captain", "You're my gunner now, lad. Don't drop the cannon."],
        ["fisher", "Red barrels go boom. That's my whole speech."],
    ],
    "1_after": [
        ["mate", "First fort down! I'll carve a notch in the mast. Captain, we have no knife."],
    ],
    "2_before": [
        ["captain", "No cannon today. Helm. The gorge is narrow and the rocks are not."],
        ["mate", "I steered a cart once. The cart lost."],
    ],
    "2_after": [
        ["captain", "Made fast, and the ship is the same shape as this morning. Well done."],
    ],
    "3_before": [
        ["king", "Captain. Yours is the only ship that came back."],
        ["king", "Also the only ship I had. Try to keep it."],
        ["captain", "...You heard none of that, lad. To your gun."],
    ],
    "3_after": [
        ["mira", "I'm Mira. I escaped their cages. The lock was a potato."],
        ["mira", "I know every fort they hold. I'll mark your chart. In pencil."],
    ],
    "4_before": [
        ["captain", "Storm swell. Green water lifts you, white water flips you."],
        ["mate", "Which one is the sky right now?"],
    ],
    "4_after": [
        ["mate", "My breakfast is still up on that last wave. Say hello to it."],
    ],
    "5_before": [
        ["fisher", "One pirate on a hill with a lookout. He thinks he's a lighthouse."],
        ["captain", "A pirate who falls off a hill is done for, lad. Make him fall."],
    ],
    "6_before": [
        ["captain", "Same gorge, by night, in fog. The rocks moved."],
        ["mate", "Rocks don't move. ...Captain, the rocks moved."],
    ],
    "6_after": [
        ["mira", "You hit the pier twice. I'm counting it as parking."],
    ],
    "7_before": [
        ["mira", "A log fort. Balls bounce off logs. So does good advice."],
        ["captain", "The powder is up in the lookouts. Knock it down, let it fall."],
    ],
    "7_after": [
        ["mate", "That keg fell off the tower and exploded. Twice, I think."],
    ],
    "8_before": [
        ["fisher", "A camp with crates all round it. No powder. Just a lot of wood."],
        ["captain", "So we knock the towers onto them. Timber solves everything."],
    ],
    "9_before": [
        ["mira", "Two guns in sandbag nests. They fire every few seconds and never hit."],
        ["captain", "One ball sets a nest alight. The second blows it. Count to two, lad."],
    ],
    "9_after": [
        ["mate", "They missed us forty times. I was starting to feel insulted."],
    ],
    "10_before": [
        ["captain", "A galleon, thirty metres off, gun to gun. Six balls sink her."],
        ["mate", "She's bigger than us. Does she know she's bigger than us?"],
    ],
    "10_after": [
        ["mate", "Her sails caught fire and she STILL kept shooting. Respect."],
    ],
    "11_before": [
        ["fisher", "Port Alder. A gun dug in on the quay. Set it alight, then blow it."],
        ["mira", "The lookouts behind have no powder. Just pirates and bad posture."],
    ],
    "11_after": [
        ["mate", "The harbour's ours! Smells like fish and freedom. Mostly fish."],
    ],
    "12_before": [
        ["fisher", "Maelstrom Lane, in a storm, at night. Lost two cousins to it."],
        ["fisher", "They were terrible cousins. Still. Keep off the throats."],
    ],
    "12_after": [
        ["mate", "I closed my eyes for the whole lane. Did it look nice?"],
    ],
    "13_before": [
        ["mira", "Eagle's Nest. A log fort on a crag. Aim high and pull hard."],
        ["captain", "The logs only fall to a blast. Find the powder, lad."],
    ],
    "14_before": [
        ["mira", "The lighthouse. Their powder is up in the lantern, next to the light."],
        ["mate", "Who keeps powder next to a light? ...Pirates. Right."],
    ],
    "14_after": [
        ["captain", "The light's out and so is the top of the tower. Tidy work."],
    ],
    "15_before": [
        ["captain", "A log keep by firelight. A gun in front of it, behind logs."],
        ["captain", "Two of your balls are powder. Don't waste them on the sea."],
    ],
    "15_after": [
        ["mira", "They knew we were coming. Someone talks."],
        ["mate", "Not me! ...Maybe the parrot. The parrot knows things."],
    ],
    "16_before": [
        ["fisher", "The lane again, with fog. You'll see the funnels when it's too late."],
        ["captain", "So we see them earlier, lad. Keep her in the middle."],
    ],
    "17_before": [
        ["mira", "The old brick tower. It won't fall. Powder on both sides of it."],
        ["captain", "Blow both stores. The big gun on top shoots back, so hurry."],
    ],
    "17_after": [
        ["mate", "That gun on the tower went up like a festival. A very loud festival."],
    ],
    "18_before": [
        ["mate", "Captain... the water's turning. The whole sea is turning."],
        ["captain", "The Eye. Rudder in the white window, lad. The window moves. So do you."],
    ],
    "18_after": [
        ["captain", "Out. I've never seen a ship come out of the Eye."],
        ["mate", "I've never seen my own lunch twice. New day, new things."],
    ],
    "19_before": [
        ["mira", "A black galleon, twice our size, in a storm by night. She fires fast."],
        ["captain", "Seven balls sink her. Every second one of hers finds us. Be quick."],
    ],
    "19_after": [
        ["mate", "She's gone! Captain, I'd like it noted I didn't scream."],
        ["captain", "Noted. You screamed."],
    ],
    "20_before": [
        ["fisher", "The sea's quiet here. Too quiet. Something big lives under it."],
        ["captain", "Then we'll meet it with the gun, lad. Load everything we have."],
    ],
    "20_after": [
        ["king", "The Kraken is dead and Valora is free. Rest, gunner."],
        ["mate", "Can I have the spoons now?"],
    ],
}

## Which scenes are overheard through a door, not spoken to you.
const EAVESDROP := ["3_before"]

## Pip after a win with no scene of its own.
const MATE_JOKES := [
    "I counted the cannonballs. Twice. We have fewer now.",
    "My mum thinks I'm a baker. Don't tell her.",
    "That pirate flew so far he'll be home before us.",
    "Nice shot! I'd clap, but I'm holding a rope.",
    "Grimhorn is going to be SO cross.",
    "That tower fell like my cousin at a wedding.",
    "The islanders brought fish! I love you, Captain.",
    "I'd have fired sooner, but I blinked.",
    "The parrot says well done. The parrot says a lot of things.",
    "I named the cannon Brenda. Brenda did great today.",
]

static func beat(id: int, when: String) -> Array:
    return BEATS.get("%d_%s" % [id, when], [])

static func is_eavesdrop(id: int, when: String) -> bool:
    return ("%d_%s" % [id, when]) in EAVESDROP

static func joke(id: int) -> String:
    return MATE_JOKES[id % MATE_JOKES.size()]
