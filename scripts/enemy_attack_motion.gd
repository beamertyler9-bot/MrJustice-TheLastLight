extends RefCounted




const DATA = {
	"rootling_sentinel": [0.6, 0.08,
		[Vector3(-0.1, 0, -0.12), Vector3(-0.18, 0.18, -0.12), Vector3(1.75, -0.45, -0.28), Vector3(0.35, 0.12, 0.48), Vector3(-0.7, -0.2, 0), Vector3(0, -0.025, 0.03), Vector3(-0.1, 0.06, -0.08)],
		[Vector3(0.17, 0, 0.1), Vector3(0.24, -0.15, 0.05), Vector3(0.62, 0.55, -0.1), Vector3(1.1, -0.2, 0.22), Vector3(-0.18, -0.45, 0), Vector3(0, -0.03, -0.08), Vector3(0.1, -0.08, -0.04)]],
	"moss_guardian": [0.72, 0.19,
		[Vector3(-0.16, 0, 0), Vector3(-0.28, 0, 0), Vector3(2.35, -0.12, -0.18), Vector3(2.35, 0.12, 0.18), Vector3(-0.28, -0.28, 0), Vector3(0, -0.04, 0.04), Vector3(-0.1, -0.1, -0.12)],
		[Vector3(0.25, 0, 0), Vector3(0.32, 0, 0), Vector3(0.35, -0.08, -0.12), Vector3(0.35, 0.08, 0.12), Vector3(-0.12, -0.12, 0), Vector3(0, -0.065, -0.1), Vector3(0.12, 0.12, -0.08)]],
	"glass_skitter": [0.54, 0.04,
		[Vector3(0.12, 0, -0.16), Vector3(-0.25, 0.38, 0.15), Vector3(0.4, -0.7, -0.7), Vector3(1.1, 0.6, 0.45), Vector3(-0.5, -0.2, 0), Vector3(0, -0.025, 0.06), Vector3(0.25, -0.25, -0.18)],
		[Vector3(-0.24, 0, 0.12), Vector3(0.38, -0.4, -0.1), Vector3(1.25, 0.55, -0.22), Vector3(0.7, -0.5, 0.7), Vector3(-0.1, -0.55, 0), Vector3(0, 0.015, -0.12), Vector3(-0.2, 0.3, -0.05)]],
	"thorn_wolf": [0.7, 0.07,
		[Vector3(0.16, 0, 0), Vector3(-0.45, 0.06, 0), Vector3(0.25, -0.1, -0.05), Vector3(0.25, 0.1, 0.05), Vector3(-0.65, -0.65, 0), Vector3(0, -0.055, 0.04), Vector3(-0.3, -0.3, -0.28)],
		[Vector3(-0.21, 0, 0.035), Vector3(0.48, -0.08, 0), Vector3(1.05, 0, -0.08), Vector3(1.05, 0, 0.08), Vector3(-0.08, -0.08, 0), Vector3(0, 0.04, -0.14), Vector3(0.32, 0.32, -0.03)]],
	"cinder_wisp": [0.58, 0.13,
		[Vector3(-0.5, 0, 0.42), Vector3(-0.32, -0.32, 0.18), Vector3(1.15, -0.65, -0.65), Vector3(0.45, 0.6, 0.75), Vector3(-0.8, -0.55, 0), Vector3(0, 0.08, 0.02), Vector3(0, 0, 0)],
		[Vector3(0.12, 0, -0.12), Vector3(0.22, 0.25, -0.12), Vector3(1.4, 0.12, -0.12), Vector3(1.15, -0.55, 0.3), Vector3(-0.12, -0.28, 0), Vector3(0, 0.16, -0.11), Vector3(0, 0, 0)]],
	"frost_brute": [0.76, 0.2,
		[Vector3(-0.24, 0, 0.05), Vector3(-0.55, 0, 0), Vector3(0.62, -0.65, -0.65), Vector3(0.62, 0.65, 0.65), Vector3(-0.9, -0.9, 0), Vector3(0, 0.015, 0.04), Vector3(-0.08, -0.08, -0.12)],
		[Vector3(0.3, 0, 0), Vector3(0.42, 0, 0), Vector3(1.15, 0.16, -0.42), Vector3(1.15, -0.16, 0.42), Vector3(-0.22, -0.22, 0), Vector3(0, -0.055, -0.08), Vector3(0.1, 0.1, -0.07)]],
	"wild_boar": [0.78, 0.15,
		[Vector3(0.21, 0, -0.035), Vector3(0.42, 0, 0), Vector3(-0.25, 0, -0.16), Vector3(-0.25, 0, 0.16), Vector3(-0.45, -0.45, 0), Vector3(0, -0.04, 0.07), Vector3(-0.24, -0.24, -0.22)],
		[Vector3(-0.13, 0, 0), Vector3(0.6, 0, 0), Vector3(0.38, 0, -0.08), Vector3(0.38, 0, 0.08), Vector3(-0.08, -0.08, 0), Vector3(0, -0.035, -0.12), Vector3(0.18, 0.18, -0.03)]],
	"cliffwarden": [0.65, 0.23,
		[Vector3(-0.19, 0, -0.2), Vector3(-0.22, -0.32, 0.1), Vector3(2.7, -0.6, -0.3), Vector3(0.35, 0.15, 0.3), Vector3(-0.25, -0.65, 0), Vector3(0, -0.035, 0.055), Vector3(-0.14, 0.08, -0.14)],
		[Vector3(0.28, 0, 0.18), Vector3(0.3, 0.22, -0.08), Vector3(0.44, 0.72, -0.18), Vector3(0.48, -0.12, 0.26), Vector3(-0.12, -0.55, 0), Vector3(0, -0.06, -0.12), Vector3(0.16, -0.1, -0.1)]],
	"stonejaw_wyrm": [0.68, 0.08,
		[Vector3(-0.38, 0, 0.12), Vector3(-0.65, 0.25, 0), Vector3(0.5, -0.3, -0.2), Vector3(0.5, 0.3, 0.2), Vector3(-0.4, -0.4, 0), Vector3(0, 0.08, 0.06), Vector3(-0.1, -0.1, 0)],
		[Vector3(0.3, 0, -0.15), Vector3(0.58, -0.25, 0), Vector3(0.15, 0.2, -0.1), Vector3(0.15, -0.2, 0.1), Vector3(-0.1, -0.1, 0), Vector3(0, 0.035, -0.15), Vector3(0.1, 0.1, 0)]],
	"fudge_golem": [0.81, 0.24,
		[Vector3(-0.22, 0, 0.14), Vector3(-0.1, -0.2, 0.15), Vector3(2.85, -0.2, -0.3), Vector3(2.45, 0.48, 0.15), Vector3(-0.72, -0.38, 0), Vector3(0, -0.075, 0.02), Vector3(-0.16, -0.08, -0.2)],
		[Vector3(0.23, 0, -0.1), Vector3(0.35, 0.2, -0.12), Vector3(0.12, 0.12, -0.36), Vector3(0.48, -0.4, 0.32), Vector3(-0.12, -0.35, 0), Vector3(0, -0.09, -0.045), Vector3(0.12, 0.08, -0.14)]],
	"wrapper_mimic": [0.56, 0.04,
		[Vector3(-0.15, 0, -0.1), Vector3(-0.65, -0.2, -0.15), Vector3(1.1, -0.48, -0.5), Vector3(1.1, 0.48, 0.5), Vector3(-0.7, -0.7, 0), Vector3(0, -0.035, 0.08), Vector3(-0.2, -0.2, -0.15)],
		[Vector3(0.25, 0, 0.08), Vector3(0.6, 0.15, 0.1), Vector3(0.2, 0.35, -0.12), Vector3(0.2, -0.35, 0.12), Vector3(-0.1, -0.1, 0), Vector3(0, 0.02, -0.14), Vector3(0.22, 0.22, -0.04)]],
	"pretzel_crawler": [0.48, 0.06,
		[Vector3(0.08, 0, -0.28), Vector3(-0.22, -0.55, 0.2), Vector3(0.85, -0.8, -0.28), Vector3(0.25, 0.2, 0.65), Vector3(-0.3, -0.65, 0), Vector3(0, -0.02, 0.04), Vector3(0.3, -0.3, -0.1)],
		[Vector3(-0.12, 0, 0.3), Vector3(0.12, 0.58, -0.22), Vector3(0.32, 0.7, -0.6), Vector3(1.2, -0.65, 0.2), Vector3(-0.65, -0.15, 0), Vector3(0, 0.025, -0.09), Vector3(-0.35, 0.35, -0.05)]],
	"cola_sloshback": [0.72, 0.12,
		[Vector3(-0.25, 0, 0.1), Vector3(-0.62, 0, 0.12), Vector3(0.3, -0.3, -0.35), Vector3(0.3, 0.3, 0.35), Vector3(-0.8, -0.8, 0), Vector3(0, -0.075, 0.05), Vector3(-0.18, -0.18, -0.24)],
		[Vector3(0.35, 0, -0.08), Vector3(0.56, 0, -0.06), Vector3(0.85, 0.25, -0.55), Vector3(0.85, -0.25, 0.55), Vector3(-0.25, -0.25, 0), Vector3(0, 0.03, -0.09), Vector3(0.22, 0.22, -0.04)]],
	"sugarspike_wasp": [0.66, 0.03,
		[Vector3(-0.28, 0, 0.2), Vector3(-0.22, -0.3, 0.12), Vector3(0.35, -0.6, -0.35), Vector3(0.35, 0.6, 0.35), Vector3(-0.5, -0.5, 0), Vector3(0, 0.16, 0.05), Vector3(-0.3, -0.3, -0.18)],
		[Vector3(0.45, 0, -0.12), Vector3(0.18, 0.1, -0.15), Vector3(1.2, 0.2, -0.15), Vector3(1.2, -0.2, 0.15), Vector3(-0.1, -0.1, 0), Vector3(0, 0.06, -0.15), Vector3(0.4, 0.4, -0.06)]],
	"grand_confectioner": [0.62, 0.15,
		[Vector3(-0.1, 0, 0.18), Vector3(-0.15, 0.3, 0.12), Vector3(2.3, -0.7, -0.2), Vector3(1.45, 0.5, 0.5), Vector3(-0.8, -0.4, 0), Vector3(0, -0.025, 0.02), Vector3(-0.15, 0.12, -0.1)],
		[Vector3(0.18, 0, -0.15), Vector3(0.22, -0.3, -0.1), Vector3(0.7, 0.55, -0.45), Vector3(1.45, -0.6, 0.2), Vector3(-0.3, -0.8, 0), Vector3(0, -0.045, -0.06), Vector3(0.18, -0.14, -0.08)]],
	"windwhistle_stalker": [0.63, 0.05,
		[Vector3(0.12, 0, -0.15), Vector3(-0.18, -0.35, 0.18), Vector3(1.0, -0.45, -0.6), Vector3(0.2, 0.3, 0.35), Vector3(-0.6, -0.4, 0), Vector3(0, -0.04, 0.035), Vector3(-0.25, 0.1, -0.18)],
		[Vector3(-0.22, 0, 0.13), Vector3(0.2, 0.35, -0.1), Vector3(1.5, 0.35, -0.2), Vector3(0.65, -0.5, 0.4), Vector3(-0.15, -0.45, 0), Vector3(0, 0.035, -0.14), Vector3(0.4, -0.2, -0.05)]],
	"thistle_jackal": [0.43, 0.04,
		[Vector3(0.08, 0, 0.22), Vector3(-0.38, 0.55, -0.15), Vector3(0.15, -0.2, -0.2), Vector3(0.65, 0.4, 0.1), Vector3(-0.45, -0.2, 0), Vector3(0.025, -0.04, 0.04), Vector3(-0.1, -0.25, -0.16)],
		[Vector3(-0.18, 0, -0.18), Vector3(0.5, -0.5, 0.12), Vector3(1.25, 0.15, -0.15), Vector3(0.75, -0.2, 0.25), Vector3(-0.1, -0.4, 0), Vector3(-0.035, 0.025, -0.13), Vector3(0.35, 0.15, -0.04)]],
	"grassland_colossus": [0.72, 0.26,
		[Vector3(-0.14, 0, -0.12), Vector3(-0.15, 0.15, 0.05), Vector3(0.4, -0.25, -0.6), Vector3(0.75, 0.4, 0.35), Vector3(-0.7, -0.5, 0), Vector3(0, 0.06, 0.02), Vector3(0.62, -0.08, -0.32)],
		[Vector3(0.18, 0, 0.1), Vector3(0.35, -0.12, -0.05), Vector3(1.15, 0.1, -0.35), Vector3(0.45, -0.3, 0.55), Vector3(-0.3, -0.2, 0), Vector3(0, -0.075, -0.04), Vector3(-0.18, 0.12, -0.06)]],
	"kiteclaw_raptor": [0.76, 0.03,
		[Vector3(-0.34, 0, -0.18), Vector3(-0.45, 0.18, 0.1), Vector3(0.4, -0.7, -0.4), Vector3(0.8, 0.25, 0.6), Vector3(-0.6, -0.4, 0), Vector3(0, 0.18, 0.035), Vector3(-0.45, -0.45, -0.35)],
		[Vector3(0.42, 0, 0.1), Vector3(0.38, -0.15, -0.08), Vector3(1.35, 0.3, -0.12), Vector3(1.35, -0.3, 0.12), Vector3(-0.15, -0.15, 0), Vector3(0, 0.045, -0.16), Vector3(0.7, 0.7, -0.1)]],
	"stormhorn_matriarch": [0.8, 0.18,
		[Vector3(0.22, 0, 0.08), Vector3(0.38, -0.65, 0.08), Vector3(0.15, -0.2, -0.2), Vector3(0.15, 0.2, 0.2), Vector3(-0.4, -0.4, 0), Vector3(0, -0.045, 0.075), Vector3(-0.35, -0.2, -0.24)],
		[Vector3(-0.2, 0, -0.07), Vector3(0.68, 0.45, -0.05), Vector3(0.65, 0.1, -0.1), Vector3(0.65, -0.1, 0.1), Vector3(-0.08, -0.08, 0), Vector3(0, -0.025, -0.18), Vector3(0.28, 0.18, -0.04)]],
	"dune_maw": [0.74, 0.12,
		[Vector3(-0.45, 0, -0.17), Vector3(-0.48, -0.35, 0.15), Vector3(0.25, -0.6, -0.4), Vector3(0.75, 0.2, 0.3), Vector3(-0.55, -0.25, 0), Vector3(0, -0.065, 0.07), Vector3(-0.1, -0.1, 0)],
		[Vector3(0.38, 0, 0.18), Vector3(0.65, 0.28, -0.12), Vector3(0.9, 0.35, -0.15), Vector3(0.35, -0.5, 0.4), Vector3(-0.15, -0.5, 0), Vector3(0, 0.09, -0.13), Vector3(0.1, 0.1, 0)]],
	"sunken_sentinel": [0.7, 0.11,
		[Vector3(-0.12, 0, -0.08), Vector3(-0.15, -0.28, 0.05), Vector3(0.7, -0.6, -0.15), Vector3(1.0, 0.18, 0.25), Vector3(-1.15, -0.8, 0), Vector3(0, -0.025, 0.035), Vector3(-0.2, 0.15, -0.1)],
		[Vector3(0.15, 0, 0.06), Vector3(0.12, 0.15, -0.04), Vector3(1.5, 0.1, -0.08), Vector3(0.85, -0.2, 0.15), Vector3(-0.05, -0.75, 0), Vector3(0, -0.03, -0.08), Vector3(0.25, -0.18, -0.06)]],
	"sandwraith": [0.66, 0.15,
		[Vector3(-0.22, 0, -0.2), Vector3(-0.18, 0.4, -0.18), Vector3(0.85, -0.85, -0.7), Vector3(1.45, 0.3, 0.4), Vector3(-0.65, -0.45, 0), Vector3(0, 0.11, 0.04), Vector3(0, 0, 0)],
		[Vector3(0.15, 0, 0.18), Vector3(0.25, -0.38, 0.12), Vector3(1.35, 0.25, -0.35), Vector3(0.55, -0.65, 0.65), Vector3(-0.15, -0.6, 0), Vector3(0, 0.18, -0.08), Vector3(0, 0, 0)]],
	"obelisk_scorpion": [0.71, 0.16,
		[Vector3(0.18, 0, 0), Vector3(-0.15, 0, 0.2), Vector3(0.65, -0.85, -0.6), Vector3(0.65, 0.85, 0.6), Vector3(-0.8, -0.8, 0), Vector3(0, -0.04, 0.06), Vector3(-0.2, -0.2, -0.18)],
		[Vector3(-0.22, 0, 0.06), Vector3(0.35, 0, -0.15), Vector3(1.1, 0.35, -0.18), Vector3(1.1, -0.35, 0.18), Vector3(-0.2, -0.2, 0), Vector3(0, 0.015, -0.1), Vector3(0.25, 0.25, -0.08)]],
	"glass_anubid": [0.6, 0.12,
		[Vector3(-0.18, 0, 0.1), Vector3(-0.3, -0.4, 0.08), Vector3(1.65, -0.2, -0.2), Vector3(0.6, 0.65, 0.5), Vector3(-0.9, -0.55, 0), Vector3(0, 0.02, 0.035), Vector3(-0.16, 0.1, -0.1)],
		[Vector3(0.22, 0, -0.08), Vector3(0.4, 0.15, -0.05), Vector3(1.35, 0.1, -0.08), Vector3(1.35, -0.1, 0.08), Vector3(-0.1, -0.1, 0), Vector3(0, -0.025, -0.12), Vector3(0.2, -0.12, -0.05)]],
	"riftback": [0.78, 0.22,
		[Vector3(0.18, 0, -0.24), Vector3(0.35, -0.4, 0.18), Vector3(0.2, -0.15, -0.35), Vector3(0.8, 0.35, 0.15), Vector3(-0.65, -0.35, 0), Vector3(0, -0.055, 0.045), Vector3(-0.15, -0.25, -0.18)],
		[Vector3(-0.16, 0, 0.25), Vector3(0.15, 0.45, -0.18), Vector3(1.0, 0.15, -0.25), Vector3(0.3, -0.2, 0.45), Vector3(-0.15, -0.55, 0), Vector3(0.04, -0.025, -0.09), Vector3(0.2, 0.3, -0.1)]],
	"furnace_hound": [0.72, 0.08,
		[Vector3(0.24, 0, -0.04), Vector3(-0.35, 0.55, 0.05), Vector3(0.4, -0.2, -0.12), Vector3(0.4, 0.2, 0.12), Vector3(-0.75, -0.75, 0), Vector3(0, -0.055, 0.07), Vector3(-0.4, -0.4, -0.25)],
		[Vector3(-0.28, 0, 0.04), Vector3(0.85, -0.4, -0.04), Vector3(1.3, 0.1, -0.1), Vector3(1.3, -0.1, 0.1), Vector3(-0.08, -0.08, 0), Vector3(0, 0.045, -0.16), Vector3(0.42, 0.42, -0.04)]],
	"slag_crawler": [0.64, 0.15,
		[Vector3(-0.2, 0, 0.18), Vector3(-0.5, 0.2, 0.2), Vector3(0.45, -0.3, -0.65), Vector3(0.95, 0.6, 0.3), Vector3(-0.55, -0.45, 0), Vector3(0, -0.05, 0.03), Vector3(-0.3, 0.15, -0.2)],
		[Vector3(0.25, 0, -0.12), Vector3(0.4, -0.2, -0.12), Vector3(1.05, 0.4, -0.25), Vector3(0.4, -0.6, 0.55), Vector3(-0.25, -0.6, 0), Vector3(0, 0.03, -0.07), Vector3(0.3, -0.2, -0.08)]],
	"ash_harpy": [0.62, 0.08,
		[Vector3(-0.2, 0, 0.26), Vector3(-0.25, 0.25, -0.2), Vector3(0.45, -0.5, -0.9), Vector3(1.15, 0.25, 0.6), Vector3(-0.55, -0.25, 0), Vector3(0, 0.14, 0.02), Vector3(-0.32, -0.1, -0.2)],
		[Vector3(0.3, 0, -0.22), Vector3(0.35, -0.2, 0.15), Vector3(1.3, 0.4, -0.35), Vector3(0.55, -0.65, 0.9), Vector3(-0.15, -0.55, 0), Vector3(0, 0.08, -0.1), Vector3(0.35, 0.22, -0.08)]],
	"root_reaper": [0.65, 0.09,
		[Vector3(-0.12, 0, -0.3), Vector3(0.3, -0.4, 0.22), Vector3(1.15, -1.05, -0.9), Vector3(0.3, 0.55, 0.55), Vector3(-1.15, -0.8, 0), Vector3(0, -0.045, 0.04), Vector3(-0.2, 0.12, -0.18)],
		[Vector3(0.18, 0, 0.26), Vector3(-0.1, 0.35, -0.18), Vector3(0.95, 0.9, -0.24), Vector3(1.15, -0.55, 0.28), Vector3(-0.85, -0.55, 0), Vector3(0, -0.06, -0.1), Vector3(0.25, -0.18, -0.08)]],
	"wraithhart": [0.74, 0.09,
		[Vector3(0.18, 0, -0.13), Vector3(0.48, 0.75, 0.08), Vector3(0.2, -0.3, -0.22), Vector3(0.2, 0.3, 0.22), Vector3(-0.5, -0.5, 0), Vector3(0, -0.025, 0.055), Vector3(-0.32, -0.32, -0.24)],
		[Vector3(-0.26, 0, 0.12), Vector3(0.75, -0.55, -0.06), Vector3(1.15, 0.15, -0.08), Vector3(1.15, -0.15, 0.08), Vector3(-0.12, -0.12, 0), Vector3(0, 0.065, -0.14), Vector3(0.38, 0.38, -0.04)]],
	"hollow_hound": [0.82, 0.07,
		[Vector3(0.22, 0, 0.15), Vector3(-0.62, 0.35, -0.12), Vector3(0.35, -0.15, -0.3), Vector3(0.65, 0.4, 0.12), Vector3(-0.9, -0.7, 0), Vector3(0, -0.075, 0.04), Vector3(-0.35, -0.3, -0.3)],
		[Vector3(-0.34, 0, -0.12), Vector3(0.72, -0.4, 0.08), Vector3(1.4, 0.2, -0.12), Vector3(1.05, -0.2, 0.3), Vector3(-0.15, -0.35, 0), Vector3(0, 0.04, -0.16), Vector3(0.45, 0.32, -0.06)]],
	"grave_creeper": [0.56, 0.12,
		[Vector3(0.18, 0, 0.28), Vector3(0.22, -0.5, -0.25), Vector3(0.25, -0.85, -0.8), Vector3(1.25, 0.3, 0.5), Vector3(-0.9, -0.2, 0), Vector3(0, -0.065, 0.025), Vector3(-0.25, 0.35, -0.3)],
		[Vector3(-0.18, 0, -0.26), Vector3(-0.2, 0.5, 0.18), Vector3(1.25, 0.65, -0.25), Vector3(0.4, -0.8, 0.85), Vector3(-0.25, -0.8, 0), Vector3(0, 0.035, -0.12), Vector3(0.35, -0.25, -0.12)]],
	"veil_moth": [0.68, 0.08,
		[Vector3(-0.15, 0, -0.3), Vector3(-0.35, -0.25, 0.25), Vector3(1.25, -0.4, -0.3), Vector3(1.25, 0.4, 0.3), Vector3(-1.0, -1.0, 0), Vector3(0, 0.14, 0.06), Vector3(-0.1, -0.1, 0)],
		[Vector3(0.25, 0, 0.24), Vector3(0.3, 0.3, -0.2), Vector3(0.3, 0.65, -0.8), Vector3(0.3, -0.65, 0.8), Vector3(-0.15, -0.15, 0), Vector3(0, 0.08, -0.1), Vector3(0.1, 0.1, 0)]],
	"thorn_widow": [0.74, 0.05,
		[Vector3(0.2, 0, -0.18), Vector3(-0.85, 0.15, 0.18), Vector3(1.3, -0.65, -0.35), Vector3(0.65, 0.85, 0.7), Vector3(-0.85, -0.55, 0), Vector3(0, -0.055, 0.04), Vector3(-0.35, -0.35, -0.3)],
		[Vector3(-0.28, 0, 0.12), Vector3(0.55, -0.2, -0.1), Vector3(0.75, 0.45, -0.7), Vector3(1.3, -0.55, 0.2), Vector3(-0.2, -0.45, 0), Vector3(0, 0.045, -0.15), Vector3(0.42, 0.42, -0.08)]],
	"mourning_knight": [0.66, 0.15,
		[Vector3(-0.08, 0, 0.18), Vector3(-0.12, 0.3, 0.06), Vector3(1.8, -0.65, -0.35), Vector3(1.05, 0.15, 0.2), Vector3(-0.7, -0.65, 0), Vector3(0, -0.025, 0.025), Vector3(-0.12, 0.1, -0.1)],
		[Vector3(0.14, 0, -0.15), Vector3(0.2, -0.25, -0.04), Vector3(0.85, 0.8, -0.55), Vector3(1.0, -0.15, 0.15), Vector3(-0.25, -0.6, 0), Vector3(0, -0.045, -0.07), Vector3(0.16, -0.12, -0.06)]],
	"pale_watcher": [0.8, 0.18,
		[Vector3(-0.15, 0, 0.12), Vector3(-0.3, 0.45, 0.14), Vector3(0.75, -0.25, -0.7), Vector3(0.15, 0.55, 0.4), Vector3(-1.0, -0.65, 0), Vector3(0, 0.12, 0.06), Vector3(0, 0, 0)],
		[Vector3(0.12, 0, -0.1), Vector3(0.25, -0.35, -0.08), Vector3(1.65, 0.05, -0.12), Vector3(0.65, -0.35, 0.5), Vector3(-0.1, -0.5, 0), Vector3(0, 0.19, -0.1), Vector3(0, 0, 0)]],
	"blackthorn_regent": [0.74, 0.21,
		[Vector3(-0.18, 0, -0.2), Vector3(-0.18, -0.3, 0.08), Vector3(2.45, -0.75, -0.28), Vector3(1.05, 0.2, 0.28), Vector3(-0.6, -0.7, 0), Vector3(0, -0.03, 0.04), Vector3(-0.18, 0.12, -0.12)],
		[Vector3(0.22, 0, 0.2), Vector3(0.25, 0.35, -0.06), Vector3(0.75, 0.85, -0.65), Vector3(0.85, -0.1, 0.18), Vector3(-0.2, -0.65, 0), Vector3(0, -0.06, -0.1), Vector3(0.2, -0.16, -0.08)]],
	"shard_sentinel": [0.65, 0.18,
		[Vector3(-0.12, 0, -0.06), Vector3(-0.12, -0.12, 0.04), Vector3(2.85, -0.15, -0.18), Vector3(1.12, 0.25, 0.12), Vector3(-0.45, -0.92, 0), Vector3(0, -0.02, 0.035), Vector3(-0.15, 0.1, -0.12)],
		[Vector3(0.19, 0, 0.05), Vector3(0.22, 0.08, -0.04), Vector3(0.38, 0.12, -0.12), Vector3(1.08, 0.2, 0.1), Vector3(-0.1, -0.88, 0), Vector3(0, -0.055, -0.08), Vector3(0.18, -0.12, -0.08)]],
	"prismstalker": [0.52, 0.04,
		[Vector3(0.1, 0, -0.28), Vector3(-0.28, -0.55, 0.2), Vector3(0.2, -0.2, -0.4), Vector3(0.9, 0.4, 0.1), Vector3(-0.75, -0.35, 0), Vector3(0.035, -0.035, 0.05), Vector3(-0.18, -0.3, -0.22)],
		[Vector3(-0.23, 0, 0.24), Vector3(0.48, 0.5, -0.15), Vector3(1.45, 0.2, -0.15), Vector3(0.85, -0.2, 0.45), Vector3(-0.12, -0.55, 0), Vector3(-0.035, 0.03, -0.16), Vector3(0.4, 0.25, -0.04)]],
	"geode_mimic": [0.76, 0.19,
		[Vector3(-0.28, 0, 0.08), Vector3(-0.7, 0, -0.15), Vector3(0.85, -0.65, -0.6), Vector3(0.85, 0.65, 0.6), Vector3(-0.9, -0.9, 0), Vector3(0, -0.05, 0.04), Vector3(-0.15, -0.15, -0.15)],
		[Vector3(0.32, 0, -0.08), Vector3(0.52, 0, 0.12), Vector3(0.4, 0.5, -0.25), Vector3(0.4, -0.5, 0.25), Vector3(-0.15, -0.15, 0), Vector3(0, 0.055, -0.09), Vector3(0.18, 0.18, -0.07)]],
	"resonance_wyrm": [0.58, 0.13,
		[Vector3(-0.25, 0, 0.3), Vector3(-0.4, 0.55, -0.2), Vector3(0.55, -0.45, -0.35), Vector3(0.15, 0.7, 0.2), Vector3(-0.65, -0.25, 0), Vector3(0, 0.07, 0.03), Vector3(-0.1, -0.1, 0)],
		[Vector3(0.35, 0, -0.28), Vector3(0.5, -0.55, 0.18), Vector3(0.2, 0.55, -0.15), Vector3(0.85, -0.3, 0.5), Vector3(-0.15, -0.6, 0), Vector3(0, 0.045, -0.12), Vector3(0.1, 0.1, 0)]],
	"glasswing_reaver": [0.7, 0.06,
		[Vector3(-0.25, 0, -0.23), Vector3(-0.2, -0.75, 0.2), Vector3(1.05, -0.75, -0.65), Vector3(0.4, 0.5, 0.8), Vector3(-0.75, -0.35, 0), Vector3(0, 0.15, 0.05), Vector3(-0.2, -0.2, -0.15)],
		[Vector3(0.32, 0, 0.2), Vector3(0.35, 0.65, -0.15), Vector3(0.5, 0.75, -0.85), Vector3(1.25, -0.5, 0.25), Vector3(-0.25, -0.7, 0), Vector3(0, 0.08, -0.13), Vector3(0.3, 0.3, -0.06)]],
	"aurora_custodian": [0.72, 0.16,
		[Vector3(-0.2, 0, 0.25), Vector3(-0.2, -0.45, 0.2), Vector3(1.65, -0.6, -0.5), Vector3(0.65, 0.75, 0.85), Vector3(-0.7, -0.4, 0), Vector3(0, 0.16, 0.05), Vector3(0, 0, 0)],
		[Vector3(0.18, 0, -0.22), Vector3(0.25, 0.4, -0.15), Vector3(0.75, 0.6, -0.75), Vector3(1.55, -0.45, 0.2), Vector3(-0.5, -0.15, 0), Vector3(0, 0.22, -0.09), Vector3(0, 0, 0)]],
}

static func _value(row: Array, index: int, progress: float, remaining: float) -> Vector3:
	var loaded: Vector3 = row[2][index]
	var contact: Vector3 = row[3][index]
	if remaining >= 0.0:
		var elapsed = 1.0 - remaining
		var keep = 1.0 - smoothstep(float(row[1]), 1.0, elapsed)

		return (contact + (contact - loaded) * sin(elapsed * PI) * 0.12) * keep
	if progress < float(row[0]): return loaded * smoothstep(0.0, float(row[0]), progress)
	return loaded.lerp(contact, smoothstep(float(row[0]), 1.0, progress))

static func _rotate(node: Node3D, offset: Vector3, weight: float) -> void:
	if node == null: return

	node.rotation = node.rotation.lerp(node.get_meta("pose_rest_rotation", Vector3.ZERO) + offset, weight)

static func apply(actor, progress: float, remaining: float, contact := false) -> void:
	if not DATA.has(actor.species_id): return
	if not contact and actor.windup <= 0.0 and actor.recovery <= 0.0 and actor.charge_time <= 0.0: return
	var row: Array = DATA[actor.species_id]
	var recovery_phase = remaining if actor.windup <= 0.0 else -1.0
	if actor.charge_time > 0.0 or contact: recovery_phase = 1.0
	var weight = 1.0
	if actor.windup > 0.0 and not contact: weight = smoothstep(0.0, 0.12, progress)
	elif recovery_phase >= 0.0: weight = smoothstep(0.0, 0.18, recovery_phase)
	var torso = _value(row, 0, progress, recovery_phase)
	actor.model.rotation.x = lerpf(actor.model.rotation.x, torso.x, weight)
	actor.model.rotation.z = lerpf(actor.model.rotation.z, torso.z, weight)
	var rest: Vector3 = actor.model.get_meta("pose_rest_position", Vector3.ZERO)
	actor.model.position = actor.model.position.lerp(rest + _value(row, 5, progress, recovery_phase), weight)
	actor.model.scale = actor.model.scale.lerp(actor.rest_scale, weight)
	_rotate(actor.head, _value(row, 1, progress, recovery_phase), weight)
	var elbows = _value(row, 4, progress, recovery_phase)
	for i in range(actor.arms.size()):
		_rotate(actor.arms[i], _value(row, 2 + i % 2, progress, recovery_phase), weight)
		if i < actor.forearms.size(): _rotate(actor.forearms[i], Vector3(elbows.x if i % 2 == 0 else elbows.y, 0, 0), weight)
	var legs = _value(row, 6, progress, recovery_phase)
	for i in range(actor.feet.size()):
		var front = 1.0 if i < 2 else 0.55
		_rotate(actor.feet[i], Vector3((legs.x if i % 2 == 0 else legs.y) * front, 0, 0), weight)
		if i < actor.knees.size(): _rotate(actor.knees[i], Vector3(legs.z * front, 0, 0), weight)
