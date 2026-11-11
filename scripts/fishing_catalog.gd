extends RefCounted
const IDS = ["lake_fish", "silver_trout", "reed_perch", "golden_carp", "moon_eel", "crystal_koi", "cola_carp", "fizzfin", "frost_char", "sunscale_bream"]
const COLORS = ["8fae9e", "a8c9d9", "93a75d", "e5b554", "8b80ad", "b18cda", "9b603b", "e8aa65", "83c9df", "e4ce79"]
static func catch_at(region: int, roll: int) -> String:
 var pool = IDS
 if region == 10: pool = ["cola_carp", "fizzfin", "golden_carp", "lake_fish"]
 elif region == 14: pool = ["frost_char", "silver_trout", "moon_eel", "lake_fish"]
 elif region == 15: pool = ["crystal_koi", "moon_eel", "silver_trout", "sunscale_bream"]
 return pool[posmod(roll, pool.size())]
