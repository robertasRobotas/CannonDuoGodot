## The story of Chapter 1, told in short scenes before and after levels, and Pip's jokes after
## every other win. Scenes play once; `seen` is saved in the player's progress.
class_name Story

## "N_before" plays before level N starts, "N_after" after it is won. Each line: [who, text].
const BEATS := {
    "1_before": [
        ["king", "Captain. The pirate Grimhorn has taken the Valora Islands. His horned brutes have built a fort on every one."],
        ["king", "They have locked our people in cages. I can give you one ship and one cannon. It will have to be enough."],
        ["king", "Free the islands. Free my people."],
        ["fisher", "Old Tomas, Captain. I've fished these waters fifty years. A word of advice: pirates keep their powder close. Hit the red barrels."],
    ],
    "1_after": [
        ["mate", "Pip, your first mate, reporting! First fort down, Captain. I'd cheer louder, but I swallowed a seagull feather."],
    ],
    "2_after": [
        ["mira", "You're the king's captain? I'm Mira. I got out of Grimhorn's cages on Gull Rock."],
        ["mira", "I know where every one of their forts is. I'll mark them on your chart. Follow me."],
    ],
    "5_before": [
        ["mira", "Their ships guard the Bay of Gulls. Two pinnaces and a gun on the rocks. Sink them before they sink you."],
    ],
    "6_before": [
        ["mira", "Port Alder, the harbour. It was the busiest port in Valora. Now it's a pirate warehouse."],
        ["fisher", "Cranes and crates fall hard, Captain. And they keep powder among the cargo."],
    ],
    "6_after": [
        ["mate", "The harbour's ours! The fishmongers are back already. It smells... victorious."],
        ["fisher", "The shipwrights of Port Alder owe you now. Remember that."],
    ],
    "8_after": [
        ["mira", "They were waiting for us tonight. They knew we were coming."],
        ["mira", "Someone is telling them where we sail."],
        ["mate", "A spy? On OUR side? I only told my mum. And the parrot. The parrot talks, Captain."],
    ],
    "10_after": [
        ["mate", "Captain! Red Bjorn's last shot cracked the hull from stem to stern! We're taking water!"],
        ["fisher", "Sail for Port Alder. The harbour you freed will mend her."],
        ["mate", "...Patched, caulked and painted. She's prettier than before. Don't tell her I said that."],
    ],
    "12_after": [
        ["mate", "Captain, wake up! They boarded us in the night while we slept off the storm..."],
        ["mate", "The cannon. They took our cannon."],
        ["fisher", "Then take mine. It's old and small and slow. But it never missed a gull."],
    ],
    "13_before": [
        ["fisher", "My old cannon shoots short and soft. Sail in close and aim higher than you think."],
    ],
    "14_before": [
        ["mira", "Fire Mountain. The pirates built right under the volcano. When it spits, it spits rocks of fire."],
    ],
    "15_before": [
        ["mira", "Skull Rock. They took your cannon there, to the vault in the cliff."],
    ],
    "15_after": [
        ["mira", "It's here! Your cannon!"],
        ["mate", "Welcome back, old girl. No offence to the fisherman's peashooter."],
        ["fisher", "None taken. It's retired now. Like me. Mostly."],
    ],
    "16_before": [
        ["mira", "At Windmill Vale some pirates are in cages too. Grimhorn locked up the ones who wanted to quit."],
        ["mira", "Free them. See what they say."],
    ],
    "16_after": [
        ["olaf", "Olaf. Ten years I rowed for Grimhorn. No more."],
        ["olaf", "Your cannon is slow to load, Captain. Let me and my brothers help. We know the work."],
        ["mate", "New crew! They're big. They're hairy. They eat a lot. I love them."],
    ],
    "17_after": [
        ["mira", "Captain, look. Letters in the treasury, with the royal seal. Signed... Lord Vesk."],
        ["vesk", "The king's own steward. For every island he betrayed, Grimhorn paid him in gold."],
        ["king", "Vesk?! He sat at my table. He will answer for this. Finish it, Captain."],
    ],
    "18_before": [
        ["olaf", "You should know who you fight. Grimhorn was a navy captain once. Like you."],
        ["olaf", "He quarrelled with the king, took his ship and sailed away. He never forgave Valora."],
    ],
    "19_after": [
        ["mira", "One island left. Grimhorn's own. The sea there is quiet. Too quiet."],
        ["mate", "Quiet is good! Quiet means nobody is shooting at me. ...Right?"],
    ],
    "20_before": [
        ["grimhorn", "So the king's little captain came at last. With one ship and one cannon."],
        ["grimhorn", "You sailed into my trap. Every ship I have is here. Every gun."],
        ["grimhorn", "I was the best captain Valora ever had. Come and see why."],
    ],
    "20_after": [
        ["grimhorn", "...You think this is over? I was never the one in charge."],
        ["mate", "Captain! A bottle in the surf, from his cabin..."],
        ["bottle", "Grimhorn. The islands were only the start. The North is ready. My ice fleet sails at the thaw. -- The Pirate King"],
        ["king", "The Valora Islands are free, Captain. My people are home. Rest now."],
        ["king", "When the ice melts, the Frozen North will need you."],
    ],
}

## Pip after a win with no scene of its own.
const MATE_JOKES := [
    "I counted the cannonballs, Captain. Then I counted them again. We have fewer now.",
    "Another fort down! My mum will be so proud. She thinks I'm a baker.",
    "That pirate flew so far he'll be home before us.",
    "Nice shot! I'd high-five you but I'm holding the rope. Which rope? Good question.",
    "I made a list of every pirate we beat. The list is on fire now. Sorry.",
    "The islanders brought fish! I love fish. I love them. I love you, Captain.",
    "Grimhorn is going to be SO cross.",
    "That tower fell like my cousin at a wedding.",
]

static func beat(id: int, when: String) -> Array:
    return BEATS.get("%d_%s" % [id, when], [])

static func joke(id: int) -> String:
    return MATE_JOKES[id % MATE_JOKES.size()]
