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
    "7_before": [
        ["mira", "Gunships in the bay. Sink them before they sink you."],
    ],
    "8_before": [
        ["fisher", "Port Alder. Their whole loot sits on that quay."],
    ],
    "8_after": [
        ["mate", "The harbour's ours! Smells like fish and freedom."],
    ],
    "10_after": [
        ["mira", "They knew we were coming. Someone talks."],
        ["mate", "Not me! ...Maybe the parrot."],
    ],
    "12_after": [
        ["mate", "Captain, the hull's cracked!"],
        ["fisher", "Port Alder will mend her. You freed them, remember?"],
    ],
    "14_after": [
        ["mate", "They boarded us in the dark. The cannon's gone."],
        ["fisher", "Take mine. Old and small... but she never missed."],
    ],
    "15_before": [
        ["fisher", "She throws short. Sail close, aim high."],
    ],
    "16_before": [
        ["mira", "Fire Mountain spits burning rock. Let it fight for you."],
    ],
    "17_before": [
        ["mira", "Skull Rock. Your cannon is in that vault."],
    ],
    "17_after": [
        ["mate", "Welcome back, old girl!"],
    ],
    "18_before": [
        ["mira", "Some pirates want out. Free them too."],
    ],
    "18_after": [
        ["olaf", "Olaf. Ten years with Grimhorn. No more."],
        ["olaf", "My brothers and I will work your gun."],
    ],
    "19_after": [
        ["mira", "Letters with the royal seal. Lord Vesk sold us out."],
        ["king", "Vesk?! He will answer. Finish this, Captain."],
    ],
    "20_before": [
        ["olaf", "Grimhorn was navy once. The best. Then the king broke him."],
    ],
    "21_after": [
        ["mira", "One island left after the vault. It's too quiet."],
    ],
    "22_before": [
        ["captain", "Their vault has one window, lad."],
        ["captain", "Thread it. Make the king proud."],
    ],
    "23_before": [
        ["captain", "Something big is circling us."],
        ["mate", "Please be dolphins. Please be dolphins."],
    ],
    "23_after": [
        ["mate", "THE WHALE LIFTED THE SHIP. I kissed the deck twice."],
        ["fisher", "The old sea looks after her own."],
    ],
    "24_before": [
        ["grimhorn", "The king's little captain. One ship. One cannon."],
        ["grimhorn", "Welcome to my trap."],
    ],
    "24_after": [
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
