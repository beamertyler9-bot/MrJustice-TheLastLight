extends RefCounted


const REQUESTS: Array = [
	{"id": "scrapper_stolen_dawn", "giver": "ironbell_resident", "owner": "Bellkeeper Oren", "name": "Who stole the morning?", "type": "story", "text": "The dawn bell swings, but makes no sound. Dissonance's Scrappers have been packing stolen voices into junk drones. Read their orders at Tinwhistle, recover our voice coil at Switchback, free the captive signal keeper, then restore the Prism relay. Bring the coil home; we will ring the morning ourselves.", "return_text": "Hear that? Morning belongs to everyone again. Dissonance can build another machine, but he cannot own our voices.", "reward": {"shard": 80, "crystal": 5}, "steps": [
		{"site": "tinwhistle_stockade", "flag": "scrapper_read_tinwhistle_stockade", "text": "Investigate the orders at Tinwhistle Stockade"},
		{"site": "switchback_roost", "flag": "scrapper_camp_switchback_roost_cleared", "text": "Clear Switchback Roost's sound shipment guards"},
		{"site": "switchback_roost", "item": "quest_scrapper_voice_coil", "text": "Recover the stolen dawn voice coil"},
		{"site": "switchback_roost", "flag": "scrapper_rescued_switchback_roost", "text": "Free the detained signal keeper at Switchback"},
		{"site": "prism_relay", "flag": "scrapper_read_prism_relay", "text": "Read the Prism relay's three-note instructions"},
		{"site": "prism_relay", "flag": "scrapper_relay_prism_relay", "text": "Clear the Prism camp and restore its three-note relay"}]},
	{"id": "scrapper_quarry_song", "giver": "ironbell_mason", "owner": "Dori Copperbraid", "name": "A chime to bring them home", "type": "story", "text": "My quarry crew used a three-tube chime to find one another in dust. The Scrappers took it to Windbreak Yard. Their shipment notes may tell us why. Read them, clear the yard and recover our chime. A tool that brings workers home is no part of a sound-blast weapon.", "return_text": "Three notes, three paths home. The crew will never mistake that sound.", "reward": {"shard": 45, "iron": 5}, "steps": [
		{"site": "windbreak_yard", "flag": "scrapper_read_windbreak_yard", "text": "Read the salvage manifest at Windbreak Yard"},
		{"site": "windbreak_yard", "flag": "scrapper_camp_windbreak_yard_cleared", "text": "Clear the Windbreak shipment yard"},
		{"site": "windbreak_yard", "item": "quest_scrapper_quarry_chime", "text": "Recover Dori's three-tube quarry chime"}]},
	{"id": "scrapper_fen_whistle", "giver": "brindlewick_gardener", "owner": "Juniper", "name": "The reed that would not sing", "type": "story", "text": "A garden guide followed the missing birdsong into Sunken Switchyard and never returned. Read the gang's orders, free the guide and bring back my reed whistle. Dissonance calls the marsh a sound mine. The people who live there call it home.", "return_text": "The guide is safe, and the reeds answer the whistle again. Let the marsh keep its own song.", "reward": {"shard": 48, "herb": 8}, "steps": [
		{"site": "sunken_switchyard", "flag": "scrapper_read_sunken_switchyard", "text": "Investigate the silence at Sunken Switchyard"},
		{"site": "sunken_switchyard", "flag": "scrapper_rescued_sunken_switchyard", "text": "Clear the camp and rescue the missing garden guide"},
		{"site": "sunken_switchyard", "item": "quest_scrapper_fen_whistle", "text": "Recover Juniper's green reed whistle"}]},
	{"id": "scrapper_ember_lullaby", "giver": "ironbell_baker", "owner": "Pella Crumb", "name": "A lullaby beneath the cinders", "type": "story", "text": "My mother's music box went missing with a relief cart. A Scrapper at Cinder Jack wrote that even a lullaby could power the boss's blast weapon. Read his orders, stop the shipment and recover the little red box. Then restore the camp relay so the relief crew can hear the all-clear.", "return_text": "It still plays. Tonight the apprentices will hear the song my mother taught me.", "reward": {"shard": 52, "tonic": 3}, "steps": [
		{"site": "cinder_jack_camp", "flag": "scrapper_read_cinder_jack_camp", "text": "Read Cinder Jack's sound-weapon requisition"},
		{"site": "cinder_jack_camp", "flag": "scrapper_camp_cinder_jack_camp_cleared", "text": "Stop the lullaby shipment at Cinder Jack Camp"},
		{"site": "cinder_jack_camp", "item": "quest_scrapper_ash_musicbox", "text": "Recover Pella's ember music box"},
		{"site": "cinder_jack_camp", "flag": "scrapper_relay_cinder_jack_camp", "text": "Restore the Cinder Jack relay for the relief crew"}]}
]
const FETCH: Dictionary = {
	"pantry_beans": {"point": Vector2(-20, -12), "area": "North kettle trail", "text": "My copper travel kettle vanished on the north road. Its little whistle has welcomed travelers for years. Find it and bring it home before the evening caravan arrives."},
	"forge_fuel": {"point": Vector2(-38, -20), "area": "Embervein forge approach", "text": "I left my red hearth bellows at the Embervein approach. Without its stamped nozzle the apprentices cannot keep an even fire. Recover the bellows; good tools deserve care."},
	"garden_wall": {"point": Vector2(-48, 29), "area": "West garden trail", "text": "My brass plumb bob slipped off the wall cart on the west garden trail. Find the green cord and bring it home. That little weight has kept three generations of walls standing straight."},
	"camp_supper": {"point": Vector2(14, 34), "area": "Village picnic meadow", "text": "I packed the festival cake tin for a picnic, then left it in the meadow. Find the star-shaped tin and bring it home. The children have already chosen tomorrow's cake."},
	"willow_remedy": {"point": Vector2(78, 23), "area": "Willow medicine trail", "text": "My jade remedy press fell from the watch cart on the willow trail. Without it I cannot measure the marsh remedy safely. Recover the press before the next watch comes home."},
	"hesters_alloy": {"point": Vector2(70, -32), "area": "Quarry test ground", "text": "My copper-sun alloy die is still at the quarry test ground. Find it and bring it back intact; its marks tell me which sample keeps its edge in winter."},
	"warm_cups": {"point": Vector2(97, 32), "area": "Old bakery road", "text": "An apprentice lost our blue dawn cup on the old bakery road. Its crescent handle is easy to recognize. Bring it home; no one should begin a baking shift feeling forgotten."},
	"core_for_bramm": {"point": Vector2(-24, -38), "area": "Embervein outer trail", "text": "My insulated core tongs are missing on the Embervein outer trail. Recover the red grip before anyone handles a warm guardian core bare-handed. Honest craft begins with looking after your crew."},
	"provisions_for_the_pass": {"point": Vector2(91, -4), "area": "High pass caravan verge", "text": "The relief crew cannot risk the high pass without my brass trail compass. Find its green north needle along the caravan verge and bring it back. A safe route is the best provision I can give them."}
}

const FETCH_ANCHOR: Dictionary = {"pantry_beans": "seed_satchel", "forge_fuel": "seed_satchel", "garden_wall": "rowans_locket", "camp_supper": "lost_spindle", "willow_remedy": "market_manifest", "hesters_alloy": "forgotten_pattern", "warm_cups": "market_manifest", "core_for_bramm": "seed_satchel", "provisions_for_the_pass": "tuning_fork"}
