## The story of Chapter 1. You are the young gunner of the last navy ship afloat; the Captain
## gives the orders. Scenes play once before or after a level; Pip jokes after the other wins.
## Lines are kept short: one thought each, never a paragraph.
class_name Story

## "N_before" plays before level N starts, "N_after" after it is won. Each line: [who, text].
## The 3_before scene is overheard through the cabin door (the eavesdrop presentation).
const BEATS := {
    "1_before": [
        ["king", "Grimhorn took our islands. Our people sit in cages."],
        ["captain", "You heard the king, lad. You're my gunner now."],
        ["fisher", "Old fisherman's tip: red barrels. Boom."],
    ],
    "1_after": [
        ["mate", "First fort down! I'll carve a notch in the mast."],
    ],
    "2_before": [
        ["captain", "No cannon work today, lad. Take the helm."],
        ["captain", "Hoist the sail and bring us into port. Mind the rocks."],
    ],
    "2_after": [
        ["captain", "Well sailed. You might make a sailor yet."],
    ],
    "3_before": [
        ["king", "Captain. Yours is the only ship that came back."],
        ["king", "The rest lie on the sea floor."],
        ["king", "Break their forts. Every last one."],
        ["captain", "...You heard none of that, lad. To your gun."],
    ],
    "3_after": [
        ["mira", "I'm Mira. I escaped their cages."],
        ["mira", "I know every fort they hold. I'll mark your chart."],
    ],
    "4_before": [
        ["captain", "Storm swell ahead. Meet the waves where they're green."],
        ["captain", "White water rolls a ship over, lad. Steer around it."],
    ],
    "4_after": [
        ["mate", "My breakfast is still up on that last wave."],
    ],
    "6_before": [
        ["mira", "The reef here hides at high water. Rocks come up without warning."],
        ["captain", "There's always a warning, lad. Bubbles. Watch for the boils."],
    ],
    "8_before": [
        ["mate", "Sails astern! Three... four of them!"],
        ["captain", "They're faster than us. Gunner, the stern chaser. Three balls each."],
    ],
    "8_after": [
        ["mate", "Did you see her masts go? DID YOU SEE?"],
    ],
    "9_before": [
        ["mira", "Gunships in the bay. Sink them before they sink you."],
    ],
    "10_before": [
        ["captain", "They'll push boats off the beach for a minute. Hold them off."],
        ["captain", "Then we take the fort. Steady now."],
    ],
    "11_before": [
        ["fisher", "Port Alder. Their whole loot sits on that quay."],
    ],
    "11_after": [
        ["mate", "The harbour's ours! Smells like fish and freedom."],
    ],
    "12_before": [
        ["fisher", "Maelstrom Lane. Lost two cousins to it. Keep off the throats."],
    ],
    "14_before": [
        ["mira", "A pirate supply ship runs this coast at night. She steers by the lighthouse."],
        ["captain", "Then we put out the light, and the reef does our work."],
    ],
    "14_after": [
        ["mate", "She went straight on. Straight ON. Into the rocks."],
    ],
    "15_after": [
        ["mira", "They knew we were coming. Someone talks."],
        ["mate", "Not me! ...Maybe the parrot."],
    ],
    "16_before": [
        ["captain", "A real ship this time, lad. A galleon. Ship against ship."],
        ["captain", "Hull shots. Her masts will go at half. Keep hitting."],
    ],
    "17_after": [
        ["mate", "Captain, the hull's cracked!"],
        ["fisher", "Port Alder will mend her. You freed them, remember?"],
    ],
    "18_before": [
        ["mate", "Captain... the water's turning. The whole sea is turning."],
        ["captain", "The Eye. Helm, lad. Hold her where I say or we go down."],
    ],
    "18_after": [
        ["captain", "Out. I've never seen a ship come out of the Eye."],
    ],
    "20_before": [
        ["mira", "The fleet died here. The king's fleet."],
        ["captain", "Mind the fires. And don't look too long, lad."],
    ],
    "21_after": [
        ["mate", "They boarded us in the dark. The cannon's gone."],
        ["fisher", "Take mine. Old and small... but she never missed."],
    ],
    "22_before": [
        ["captain", "Guns on both cliffs. They'll fire where they think we'll be."],
        ["captain", "A ring of white shows where the ball lands. Be anywhere else."],
    ],
    "23_before": [
        ["fisher", "She throws short. Sail close, aim high."],
    ],
    "24_before": [
        ["captain", "Night raid. The harbour's asleep."],
        ["captain", "Every ball hits something, or the bell rings and they all wake up."],
    ],
    "25_before": [
        ["mira", "Fire Mountain spits burning rock. Let it fight for you."],
    ],
    "26_before": [
        ["mira", "A merchant carries grain to the freed islands. The pirates want her."],
        ["captain", "Boats will race for her side. Not one reaches her, gunner."],
    ],
    "27_before": [
        ["mira", "Skull Rock. Your cannon is in that vault."],
    ],
    "27_after": [
        ["mate", "Welcome back, old girl!"],
    ],
    "28_before": [
        ["captain", "A rope bridge between the towers. Pirates running across it."],
        ["captain", "Don't shoot the pirates, lad. Shoot the bridge."],
    ],
    "29_before": [
        ["mira", "Some pirates want out. Free them too."],
    ],
    "29_after": [
        ["olaf", "Olaf. Ten years with Grimhorn. No more."],
        ["olaf", "My brothers and I will work your gun."],
    ],
    "30_before": [
        ["fisher", "Shark Bay. Nobody swims there. Nobody swims there twice."],
    ],
    "31_after": [
        ["mira", "Letters with the royal seal. Lord Vesk sold us out."],
        ["king", "Vesk?! He will answer. Finish this, Captain."],
    ],
    "32_before": [
        ["mate", "Captain! Pirates! In the SKY!"],
        ["captain", "Balloons. Shoot the canvas while they're over their own fort."],
    ],
    "33_before": [
        ["olaf", "Grimhorn was navy once. The best. Then the king broke him."],
    ],
    "34_before": [
        ["mira", "The Hollow cuts a day off the voyage. Through the cliff."],
        ["captain", "Quiet in there. The roof doesn't like noise."],
    ],
    "35_after": [
        ["mira", "One island left after the vault. It's too quiet."],
    ],
    "36_before": [
        ["captain", "Their vault has one window, lad."],
        ["captain", "Thread it. Make the king proud."],
    ],
    "37_before": [
        ["captain", "Something big is circling us."],
        ["mate", "Please be dolphins. Please be dolphins."],
    ],
    "37_after": [
        ["mate", "THE WHALE LIFTED THE SHIP. I kissed the deck twice."],
        ["fisher", "The old sea looks after her own."],
    ],
    "38_before": [
        ["grimhorn", "The king's little captain. One ship. One cannon."],
        ["grimhorn", "Welcome to my trap."],
    ],
    "38_after": [
        ["bottle", "\"The islands were the start. My ice fleet sails at the thaw. — The Pirate King\""],
        ["king", "Valora is free. Rest, gunner. The North will need you soon."],
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
]

static func beat(id: int, when: String) -> Array:
    return BEATS.get("%d_%s" % [id, when], [])

static func is_eavesdrop(id: int, when: String) -> bool:
    return ("%d_%s" % [id, when]) in EAVESDROP

static func joke(id: int) -> String:
    return MATE_JOKES[id % MATE_JOKES.size()]
