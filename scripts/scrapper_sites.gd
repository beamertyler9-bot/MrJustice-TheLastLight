extends RefCounted


const RECORDS = [
	{"id": "tinwhistle_stockade", "name": "Tinwhistle Stockade", "region": 9, "layout": "stockade", "heading": 0.0, "anchors": [Vector2(1145.072, 257.4451), Vector2(1044.556, 291.5657), Vector2(1176.13, 141.5341), Vector2(972.5573, 286.8352)]},
	{"id": "switchback_roost", "name": "Switchback Roost", "region": 9, "layout": "quarry", "heading": 0.55, "anchors": [Vector2(-783.6718, -938.9956), Vector2(-1061.445, -1033.287), Vector2(-696, -923.8), Vector2(-1175.688, -945.6254)]},
	{"id": "cocoa_courtyard", "name": "Cocoa Courtyard", "region": 10, "layout": "round", "heading": -0.4, "anchors": [Vector2(481.0514, 1667.202), Vector2(481.0514, 1476.798), Vector2(560.3239, 1455.118), Vector2(598.3574, 1546.939)]},
	{"id": "windbreak_yard", "name": "Windbreak Yard", "region": 11, "layout": "quarry", "heading": 0.8, "anchors": [Vector2(2807.342, 1352.68), Vector2(2592.139, 1425.732), Vector2(2568.368, 1368.343), Vector2(2576.476, 1306.758)]},
	{"id": "sunken_switchyard", "name": "Sunken Switchyard", "region": 12, "layout": "round", "heading": -0.8, "anchors": [Vector2(6518.866, 2379.922), Vector2(6481.051, 2429.202), Vector2(6439.058, 2218.089), Vector2(6518.866, 2288.078)]},
	{"id": "cinder_jack_camp", "name": "Cinder Jack Camp", "region": 13, "layout": "quarry", "heading": 0.0, "anchors": [Vector2(5416.942, -481.9111), Vector2(5521.051, -461.2024), Vector2(5558.866, -411.922), Vector2(5392.894, -232.9613)]},
	{"id": "hushwood_palisade", "name": "Hushwood Palisade", "region": 14, "layout": "stockade", "heading": 0.3, "anchors": [Vector2(3001.544, -774.2574), Vector2(3222.35, -866.5812), Vector2(2889.467, -714.2574), Vector2(2952.732, -866.9924)]},
	{"id": "prism_relay", "name": "Prism Relay", "region": 15, "layout": "round", "heading": -0.3, "anchors": [Vector2(4952.078, -75.13446), Vector2(4882.089, -154.9417), Vector2(4942.095, 22.63998), Vector2(4998, 54)]},
	{"id": "dissonance_stronghold", "name": "Dissonance’s Soundfoundry", "region": 9, "layout": "stronghold", "heading": 0.0, "radius": 81.0, "anchors": [Vector2(-976, -100), Vector2(-1120, 260), Vector2(-1048, -748), Vector2(-760, -244)]}
]
const NOTES = {
	"tinwhistle_stockade": "Dissonance's orders: 'The valley thinks its dawn chorus belongs to everyone. Cute. Bottle the first whistle, strip the chimes, and get my voice coil to Switchback. I want a weapon that makes the whole road listen.' A margin sketch shows a junk-built drone carrying a stoppered sound jar.",
	"switchback_roost": "Dispatch to the Roost: 'My sound-blast rig needs the stolen dawn coil. Don't waste it warning the little hero. You are Scrappers: replaceable parts, like the rest of this pile. — Dissonance.' A detained traveler has scratched LOW • MIDDLE • HIGH beneath the seal.",
	"cocoa_courtyard": "The baker's missing kitchen bells hang beside tins marked LAUGHTER. A Scrapper tally reads: 'Boss says even a kettle's song can power his drones. Keep the sweet sounds separate. He hates it when we improvise.'",
	"windbreak_yard": "A quarry chime is clamped into a salvaged listening horn. 'Dissonance wants the wagon-road rhythms before market day. Three notes will reopen the relay: low, middle, high. Don't let the boss hear you humming.'",
	"sunken_switchyard": "A reed whistle is tagged with its traveler's name. 'Stolen sounds keep leaking into the sand. Boss says seal the jars or he'll test the sound blaster on us. The traveler knows how to tune the bells. Keep them here.'",
	"cinder_jack_camp": "Cinder Jack's complaint: 'He takes a family's music box and calls it fuel. Now he wants my crew to hold the ash road while his scrap drones leave us behind. Dissonance always gives orders from somewhere safer.'",
	"hushwood_palisade": "The hollow trees are silent around stacks of sound jars. A crumpled order says: 'Fear is useful. Silence is mine to sell. Keep the prisoners breathing; I haven't collected their voices yet. — Dissonance.'",
	"prism_relay": "A prism lens splits one stolen chord into three lights. The repair card reads: 'Ground the bass: LOW. Align the heart: MIDDLE. Release the sky: HIGH.' Dissonance has crossed out 'release' and written 'obey'. Returning this chord will reopen the frontier's listening line.",
	"dissonance_stronghold": "SOUNDFOUNDRY — final requisition. Five Scrappers guard the stolen voices. The Scout watches the gate, the walking Sound-Blast guards the yard, and the Echo tests three pulses at once. Dissonance waits on the rear stage: 'Let my crew wear the little hero down. When every last one is spent, I will give him a performance he cannot forget.' A worker has scratched a reply beneath it: 'We were people before you called us parts.' Free the soundfoundry, then restore its three-note relay so the valley can hear itself again."
}
static func records() -> Array: return RECORDS.duplicate(true)



const ANCHOR_LIMIT := 1028
static func anchor(record: Dictionary, index: int) -> Vector2:
	if index < record.anchors.size(): return record.anchors[index]
	var extra = index - record.anchors.size()
	return record.anchors[0] + Vector2.from_angle(float(extra % 32) * TAU / 32) * (72.0 + floori(float(extra) / 32.0) * 24.0)
