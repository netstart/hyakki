extends SceneTree
## Gera o conjunto de ícones de habilidade (armas, evoluções, uniões, passivas, melhorias do
## santuário e Kami) em assets/art/ui/skill_icons/<grupo>/<id>.png, todos 24x24 pixel art.
##
## Cada ícone = moldura da categoria + fundo em degradê da cor do elemento (pontilhado 2x2,
## sem degradê liso) + brilho de canto + silhueta com contorno escuro de 1 px e sombra.
## As silhuetas são desenhadas aqui (ASCII ou código) ou vêm dos itens do Ninja Adventure
## (CC0) já copiados para assets/art/items. Reprodutível: rodar de novo gera os mesmos bytes.
##
## Uso: Godot --headless --path . --script res://tools/gen_skill_icons.gd
##      (depois: Godot --headless --path . --import, para criar os .import)

const SIZE := 24
const INNER := 18          # área do fundo (3 px de moldura de cada lado)
const OUT_DIR := "res://assets/art/ui/skill_icons/"
const ITEMS := "res://assets/art/items/"

# --- Paleta das silhuetas (letra -> cor) --------------------------------------------------
const PAL := {
	"K": "120a18", "k": "2c1f33",
	"W": "ffffff", "L": "e4ecf4", "S": "a9b6c8", "D": "66708a",
	"Y": "fff0a0", "G": "f4b43c", "O": "b06a1c",
	"R": "e8483a", "r": "8e2030",
	"B": "a86c3c", "b": "5e3a22",
	"P": "f6ecd0", "p": "c9ae80",
	"F": "ffe08a", "f": "ff8a2a", "e": "d2402a",
	"T": "fff47a", "t": "ffc42a",
	"V": "c4a0ff", "v": "7a52d8",
	"C": "c8fcff", "c": "52cdf0", "n": "2273b0",
	"A": "d8fff2", "a": "62e4c0", "q": "2a9a8a",
	"M": "ecc4ff", "m": "a858e8", "u": "5c2a90",
	"g": "9ae870", "j": "3a9a4a",
	"H": "ff9cb0", "h": "d04a6a",
	"N": "3a2e4a", "I": "6a7ef0", "i": "3442a0",
}

# --- Fundos por elemento: [claro, médio, escuro] -----------------------------------------
const ELEMENTS := {
	"blade": ["9cc4f4", "4468b0", "16204e"],
	"fire": ["ffc070", "d8542a", "4e0e12"],
	"thunder": ["ffe680", "8a5ae0", "221058"],
	"wind": ["a0f4dc", "2a9a8e", "0c3440"],
	"spirit": ["b4f6ff", "3a9ed8", "122462"],
	"poison": ["dcaaff", "7a3ab8", "240a44"],
	"holy": ["fff2b8", "dca048", "5a2c0c"],
	"dawn": ["ffe08a", "e8603a", "3e1238"],
	"crimson": ["ff9a8a", "b0202a", "34060e"],
	"jade": ["b8f4a8", "3a9a5a", "0c3422"],
	"rose": ["ffb8c8", "d04a6a", "420c24"],
	"night": ["c8d0ff", "4a4aa8", "120e38"],
}

# --- Molduras por categoria: [aro claro, aro médio, aro escuro, linha interna] ------------
const FRAMES := {
	"weapon": ["eef4fb", "a4b2c6", "56607a", "1a1626"],
	"evolution": ["fff6b8", "f2b23a", "9a5410", "3a1a06"],
	"union": ["fff6b8", "f2b23a", "9a5410", "3a1a06"],
	"passive": ["f0c890", "b47a44", "623a1e", "22140c"],
	"powerup": ["c8f0dc", "5aa88a", "2a5e4c", "0e2420"],
	"kami": ["ffb0a0", "dc4a32", "7a1814", "2a0806"],
}
const OUTLINE := "0d0812"

# ASCII das silhuetas (sem contorno: o gerador põe o contorno de 1 px).
const ART := {
	"katana": [
		"..............W",
		".............LS",
		"............LS.",
		"...........LS..",
		"..........LS...",
		".........LS....",
		"........LS.....",
		".......LS......",
		"..G...LS.......",
		"...G.YO........",
		"....GG.........",
		"...NPG.........",
		"..PN..G........",
		".NP............",
		"OO.............",
	],
	"ofuda": [
		"PPPPPPPp",
		"PRRRRRPp",
		"PPPPPPPp",
		"PPPRPPPp",
		"PRRRRRPp",
		"PPPRPPPp",
		"PPRPRPPp",
		"PRPPPRPp",
		"PPPPPPPp",
		"PPRRRPPp",
		"PPRPRPPp",
		"PPRRRPPp",
		"PPPPPPPp",
		"ppppppp.",
	],
	"incense": [
		"..L..L...L..",
		"...L..L.L...",
		"..L..L...L..",
		"...F..F..F..",
		"...B..B..B..",
		"...B..B..B..",
		"..GGGGGGGG..",
		".GYYYYYYYYG.",
		".OGGGGGGGGO.",
		"..OGGGGGGO..",
		"...OOOOOO...",
	],
	"kusarigama": [
		"..LLLLLL......",
		".LWWWSSSLB....",
		"LSS....DSBB...",
		"S.......BB....",
		"........BB....",
		".........BB...",
		".........BB...",
		"..........Bb..",
		"..........OO..",
		".........SD...",
		"........SD....",
		".......SD.....",
		"......SD......",
		"....SSL.......",
		"...SLLSD......",
		"....DDD.......",
	],
	"bolt": [
		"....WTTTT",
		"...WTTTt.",
		"...TTTt..",
		"..TTTt...",
		"..TTTTTTT",
		".WTTTTTt.",
		".....TTt.",
		"....TTt..",
		"....TTt..",
		"...TTt...",
		"...Tt....",
		"..Tt.....",
		"..t......",
	],
	"taiko": [
		".b.........b.",
		"..b.......b..",
		"...b.....b...",
		"....B...B....",
		"..PPPPPPPPP..",
		".PPPPPPPPPPP.",
		".YpppppppppY.",
		"RRRRRRRRRRRRr",
		"RYRRRRRRRRRYr",
		"HRRRRRRRRRRRr",
		"HRRRRRRRRRRRr",
		"RYRRRRRRRRRYr",
		".YpppppppppY.",
		"..ppppppppp..",
	],
	"wisp": [
		"........c.",
		".......cC.",
		"......cCc.",
		".....cCc..",
		"...ccCCc..",
		"..cCCCCCc.",
		".cCCWWCCc.",
		".cCWWWWCc.",
		"cCWWWWWWCc",
		"cCWWWWWWCc",
		"cCCWWWWCCc",
		".cCCCCCCc.",
		"..cccccc..",
	],
	"lantern": [
		"...NNNNN...",
		"..PPPPPPP..",
		".PPPPPPPPP.",
		"PPkkkPPPPPp",
		"PkWWkPPPPPp",
		"PkWkkPPPPPp",
		"ppkkkpppppp",
		"PPPPPPPPPPp",
		"PPkkkkkkPPp",
		"pppRRRppppp",
		"PPPRRPPPPPp",
		".PPRRPPPPp.",
		"..PPRPPPp..",
		"...NNNNN...",
	],
	"paper_lantern": [
		"...NNNNN...",
		"..FFFFFFF..",
		".FFFFFFFFf.",
		"FFFWFFFFFFf",
		"fffffffffff",
		"FFWFFFFFFFf",
		"FFFFRRFFFFf",
		"fffRffRffff",
		"FFFFRRFFFFf",
		"fffffffffff",
		"FFFFFFFFFFf",
		".FFFFFFFFf.",
		"..fffffff..",
		"...NNNNN...",
	],
	"tornado": [
		"AAAAAAAAAAAAA",
		".aAAWAAAAAAa.",
		"..aaaaaaaaa..",
		"...AAAAAAAA..",
		"....aaaaaa...",
		".....AWAAA...",
		"....aaaa.....",
		"....AAA......",
		".....aa......",
		"......A......",
		".......a.....",
	],
	"magnet": [
		"WLS...WLS",
		"LSD...LSD",
		"HRr...HRr",
		"HRr...HRr",
		"HRr...HRr",
		"HRRr.HRRr",
		".HRRRRRr.",
		"..rrrrr..",
	],
	"fox": [
		".P.......P.",
		".PR.....RP.",
		".PRP...PRP.",
		".PPPPPPPPP.",
		"PPPPPPPPPPp",
		"PRRPPPPPRRp",
		"PPkRPPPRkPp",
		"PPPPPPPPPPp",
		".PPPPPPPPp.",
		"..PPPPPPp..",
		"...PPRPp...",
		"....PkP....",
		".....p.....",
	],
	"maneki": [
		"PP...........",
		"PPP..........",
		"PPP..P.....P.",
		"PPP.PHP...PHP",
		".PPPPPPPPPPPp",
		".PPPPPPPPPPPp",
		"..PPkPPPPkPPp",
		"..PPPPPHPPPPp",
		"..PPPPkkkPPPp",
		"..RRRRRGRRRRr",
		"..PPPPPOPPPPp",
		"..PPPPPPPPPPp",
		"...ppppppppp.",
	],
	"hannya": [
		"G.........G",
		"GG.......GG",
		".GPPPPPPPG.",
		".PPPPPPPPP.",
		"PkkPPPPPkkp",
		"PGkkPPPkkGp",
		"PPPPPkPPPPp",
		"PPPPPPPPPPp",
		"PrrrrrrrrrP",
		"PrWrWrWrWrp",
		".PrrrrrrrP.",
		"..PPPPPPp..",
		"...ppppp...",
	],
	"sake": [
		"...WP........",
		"...PP........",
		"...PP........",
		"..PPPp.......",
		".PPPPPp......",
		"PPPPPPPp.....",
		"PIIIIIPp.....",
		"PIPIPIPp.....",
		"PIIIIIPp.....",
		"PPPPPPPp.ppp.",
		"PPPPPPPp.PRPp",
		".pPPPPp...Pp.",
		"..ppppp...p..",
	],
	"geta": [
		"...FFFFFFFFFB.",
		"..pRpppppppRB.",
		"..ppRpppppRpB.",
		".pppRRpppRRpB.",
		".ppppRRpRRppB.",
		"ppppppWRppppB.",
		"BBBBBBBBBBBBb.",
		"bbbbbbbbbbbbb.",
		".Bb.......Bb..",
		".Bb.......Bb..",
		".bb.......bb..",
	],
	"bolt_s": [
		"...TT",
		"..TT.",
		".TT..",
		"TTTTT",
		"..TT.",
		".TT..",
		".T...",
		"T....",
	],
	"heart": [
		"..RRR...RRR..",
		".RHWRR.RRRRr.",
		"RHWRRRRRRRRRr",
		"RHRRRRRRRRRRr",
		"RRRRRRRRRRRRr",
		".RRRRRRRRRRr.",
		"..RRRRRRRRr..",
		"...RRRRRRr...",
		"....RRRRr....",
		".....RRr.....",
		"......r......",
	],
	"gi": [
		"...PPP.PPP...",
		"PPPPPPkPPPPPp",
		"PPPPPkPkPPPPp",
		"PPPPkPPPkPPPp",
		"PPPPPkPkPPPPp",
		"PPPP.PkP.PPPp",
		"pppp.PkP.pppp",
		"....NNNNN....",
		"....PPPkp....",
		"....PPPPp....",
		"....ppppp....",
	],
	"sprout": [
		"......W......",
		".....WgW.....",
		"....WgggW....",
		".....jgj.....",
		"gg...jg...gg.",
		"ggg..jg..ggg.",
		"jggg.jg.gggj.",
		".jjgjjggjjj..",
		"...jjjgjj....",
		".....jg......",
		"...BBBBBB....",
		"..BBBBBBBb...",
		"...bbbbbb....",
	],
	"chevrons": [
		"L....L....",
		"LL...LL...",
		".LL...LL..",
		"..LL...LL.",
		"...LS...LS",
		"..LS...LS.",
		".LS...LS..",
		"LS...LS...",
		"S....S....",
	],
	"kabuto": [
		"G.........G",
		"YG.......GO",
		".YG.....GO.",
		"..YGG.GGO..",
		"....GGG....",
		"...NNNNN...",
		"..NLNNNNN..",
		".NLNNNNNNN.",
		"NNNNNNNNNNN",
		"IiIiIiIiIiI",
		"NNN.....NNN",
		"IiI.....IiI",
	],
	"pagoda": [
		".....G.....",
		".....G.....",
		"...NNNNN...",
		"N.NNNNNNN.N",
		".NNNNNNNNN.",
		"...RPRPR...",
		"..NNNNNNN..",
		"NNNNNNNNNNN",
		"..RPRPRPR..",
		"..RPRPRPR..",
		".NNNNNNNNN.",
		"NNNNNNNNNNN",
		"..RRPPPRR..",
		"..RRPPPRR..",
	],
	"lotus": [
		".....H.....",
		"....HWH....",
		"..H.HWH.H..",
		".HWHHWHhWH.",
		".HWHHWHhWh.",
		"HHHhHWHhHhh",
		".hHhhhhhhh.",
		"gjggggggggj",
		".jjjjjjjjj.",
	],
	"peach": [
		"......jg...",
		".....gjgg..",
		"..HHHgjHH..",
		".HWHHHhHHh.",
		"HWHHHHhHHHh",
		"HHHHHhHHHHh",
		"HHHHHhHHHHh",
		"HHHHhHHHHhh",
		".HHHhHHHhh.",
		"..hhhhhhh..",
	],
	"skull": [
		"...PPPPP...",
		".PPPPPPPPP.",
		"PPWPPPPPPPp",
		"PPNNPPPNNPp",
		"PPNNPPPNNPp",
		"PPPPPNPPPPp",
		".pPPPPPPPp.",
		"..PkPkPkp..",
		"..ppppppp..",
	],
	"cloud": [
		"....SLL......",
		"..SLLWLLS....",
		".SLLLLLLLSLS.",
		"SLLLLLLLLLLLS",
		"DSSSSSSSSSSSD",
		".DDDDDDDDDDD.",
	],
	"wave": [
		"....ccccc....",
		"..ccCCCCCc...",
		".cCCnnnCWCc..",
		"cCn....cWWc..",
		"cn...c..CWc..",
		"cn..cWc.cC...",
		"cC..cCc......",
		".cC..........",
		"WcCc...cccc..",
		"CccCcccCCCCc.",
		"nCCCCCCCCnnCc",
		".nnnnnnnn..nn",
	],
	"spiral": [
		"...aaaaa....",
		".aaAAAAAaa..",
		"aAA.....AAa.",
		"aA..aaaa..Aa",
		"aA.aAAAAa.Aa",
		"aA.aA..Aa.Aa",
		"aA.aA.AAa.A.",
		"aA..aAa..Aa.",
		".aA.....Aa..",
		"..aAAAAAa...",
		"....aaa.....",
	],
	"puff": [
		"...MMM.......",
		"..MMMMM.MMM..",
		".MMMMMMMMMMM.",
		"MMMMMMMMMMMMm",
		"mMMMMMMMMMMmm",
		".mmmmmmmmmmm.",
	],
	"shuriken_s": [
		"...L....",
		"...LS...",
		"...LSS..",
		"LLLDDSSS",
		"SSSDDLLL",
		"..SSL...",
		"...SL...",
		"....L...",
	],
	"kunai_s": [
		".......W",
		"......LS",
		".....LS.",
		"....LS..",
		"...NS...",
		"..NN....",
		".G......",
		"G.G.....",
	],
	"tsurugi": [
		"...W...",
		"..WLS..",
		"..LLS..",
		"..LLS..",
		"..LLS..",
		"..LLS..",
		"..LLS..",
		"..LLS..",
		"GGYGGGO",
		"..BBb..",
		"..BBb..",
		"..GOO..",
	],
	"x_mark": [
		"RR....RR",
		"RRR..RRr",
		".RRRRRr.",
		"..RRRr..",
		"..RRRr..",
		".RRrRRr.",
		"RRr..RRr",
		"Rr....rr",
	],
	"cross": [
		".WW.",
		"WWWW",
		"WWWW",
		".WW.",
	],
	"plus": [
		"..W..",
		"..W..",
		"WWWWW",
		"..W..",
		"..W..",
	],
}

# Recolorações (troca de letras) para variantes.
const RECOLOR := {
	"dawn_blade": {"L": "Y", "S": "G", "W": "W", "N": "r", "P": "R", "G": "F"},
	"thunder_blade": {"L": "T", "S": "V", "W": "W", "N": "v", "P": "T", "G": "t", "Y": "T", "O": "v"},
	"oni_blade": {"N": "r", "P": "R", "G": "O", "Y": "G"},
	"blood_blade": {"L": "L", "S": "R", "N": "N", "P": "G", "G": "Y", "Y": "W"},
	"gold_fill": {"T": "Y", "t": "G", "W": "W"},
	"white_bolt": {"T": "W", "t": "C", "W": "W"},
	"violet_bolt": {"T": "M", "t": "V", "W": "W"},
	"reaper": {"L": "M", "S": "m", "B": "N", "b": "N", "O": "R", "D": "u", "N": "r"},
	"spirit_smoke": {"L": "C", "B": "N", "G": "c", "Y": "C", "O": "n", "F": "W"},
	"gold_wisp": {"c": "G", "C": "Y", "W": "W"},
	"green_heart": {"R": "g", "r": "j", "H": "W"},
	"poison_skull": {"P": "g", "p": "j", "W": "W"},
	"gold_ofuda": {"P": "Y", "p": "G", "R": "r"},
}

## Lista de ícones: [grupo, id, categoria da moldura, elemento, camadas]
## camada: "art:nome" | "art:nome@recolor" | "item:caminho" | "code:nome" | com ">dx,dy" e "|flip".
var _specs: Array = [
	# Armas base
	["weapons", "katana", "weapon", "blade", ["art:katana"]],
	["weapons", "shuriken", "weapon", "blade", ["item:projectile/shuriken.png"]],
	["weapons", "kunai", "weapon", "blade", ["item:projectile/kunai.png"]],
	["weapons", "ofuda", "weapon", "spirit", ["art:ofuda"]],
	["weapons", "incense", "weapon", "poison", ["art:incense"]],
	["weapons", "kusarigama", "weapon", "blade", ["art:kusarigama"]],
	["weapons", "smoke_bomb", "weapon", "poison", ["art:puff>0,4", "item:projectile/bomb.png>0,-1"]],
	["weapons", "raijin", "weapon", "thunder", ["art:bolt"]],
	["weapons", "fujin_fan", "weapon", "wind", ["code:fan"]],
	["weapons", "yumi", "weapon", "blade", ["code:bow"]],
	["weapons", "taiko", "weapon", "fire", ["art:taiko"]],
	["weapons", "hitodama", "weapon", "fire", ["art:wisp"]],
	["weapons", "kaminari", "weapon", "thunder", ["art:bolt>2,4", "art:cloud>0,-5"]],
	["weapons", "inazuma", "weapon", "thunder", ["code:zigzag"]],
	["weapons", "onikiri", "weapon", "crimson", ["art:katana@oni_blade|flip"]],
	# Evoluções
	["weapons", "dawn_blade", "evolution", "dawn", ["code:sun_small>4,-4", "art:katana@dawn_blade"]],
	["weapons", "steel_storm", "evolution", "blade", ["art:shuriken_s>-4,-4", "art:shuriken_s>4,-3", "art:shuriken_s>0,4"]],
	["weapons", "thousand_needles", "evolution", "blade", ["art:kunai_s>-4,-3", "art:kunai_s>0,0", "art:kunai_s>4,3"]],
	["weapons", "amaterasu_barrier", "evolution", "holy", ["code:sun", "art:ofuda>0,1"]],
	["weapons", "temple_smoke", "evolution", "spirit", ["art:incense@spirit_smoke"]],
	["weapons", "reaper_chain", "evolution", "poison", ["art:kusarigama@reaper"]],
	["weapons", "poison_mist", "evolution", "poison", ["code:mist", "art:skull@poison_skull>0,-2"]],
	["weapons", "raijin_fury", "evolution", "thunder", ["art:bolt@violet_bolt>-4,-1", "art:bolt@violet_bolt>4,1", "art:bolt@white_bolt"]],
	["weapons", "fujin_hurricane", "evolution", "wind", ["art:tornado"]],
	["weapons", "hachiman_arrow", "evolution", "holy", ["code:gold_arrow"]],
	["weapons", "ritual_thunder", "evolution", "thunder", ["art:taiko>0,2", "art:bolt@white_bolt>0,-3"]],
	["weapons", "inverted_procession", "evolution", "fire", ["art:lantern"]],
	["weapons", "takemikazuchi", "evolution", "thunder", ["art:tsurugi>-2,0", "art:bolt@white_bolt>3,1"]],
	["weapons", "raikiri", "evolution", "thunder", ["art:katana@thunder_blade", "code:sparks"]],
	["weapons", "dojigiri", "evolution", "crimson", ["code:slash_arc", "art:katana@blood_blade|flip"]],
	# Uniões
	["weapons", "fujin_raijin", "union", "thunder", ["code:fan>0,1", "art:bolt@white_bolt>1,-1"]],
	["weapons", "hundred_blades", "union", "blade", ["art:katana", "art:katana|flip"]],
	# Passivas
	["passives", "sake", "passive", "crimson", ["art:sake"]],
	["passives", "jade", "passive", "jade", ["item:resource/GemGreen.png"]],
	["passives", "scroll", "passive", "spirit", ["item:scroll/Scroll.png"]],
	["passives", "sandals", "passive", "wind", ["art:geta"]],
	["passives", "carp_heart", "passive", "rose", ["art:heart"]],
	["passives", "gi", "passive", "blade", ["art:gi"]],
	["passives", "hourglass", "passive", "holy", ["item:object/Hourglass.png"]],
	["passives", "tengu_feather", "passive", "wind", ["item:resource/feather.png"]],
	["passives", "rosary", "passive", "poison", ["code:rosary"]],
	["passives", "kitsune_magnet", "passive", "spirit", ["art:magnet"]],
	["passives", "maneki", "passive", "holy", ["art:maneki"]],
	["passives", "noh_mask", "passive", "poison", ["art:hannya"]],
	# Melhorias do santuário
	["powerups", "pu_might", "powerup", "crimson", ["art:sake"]],
	["powerups", "pu_armor", "powerup", "blade", ["art:gi"]],
	["powerups", "pu_max_hp", "powerup", "rose", ["art:heart"]],
	["powerups", "pu_regen", "powerup", "jade", ["art:heart@green_heart", "art:plus>4,3"]],
	["powerups", "pu_cooldown", "powerup", "spirit", ["item:scroll/Scroll.png"]],
	["powerups", "pu_area", "powerup", "jade", ["item:resource/GemGreen.png"]],
	["powerups", "pu_speed", "powerup", "wind", ["art:geta"]],
	["powerups", "pu_duration", "powerup", "holy", ["item:object/Hourglass.png"]],
	["powerups", "pu_amount", "powerup", "poison", ["code:rosary"]],
	["powerups", "pu_magnet", "powerup", "spirit", ["art:magnet"]],
	["powerups", "pu_luck", "powerup", "holy", ["art:maneki"]],
	["powerups", "pu_growth", "powerup", "jade", ["art:sprout"]],
	["powerups", "pu_greed", "powerup", "holy", ["code:koban"]],
	["powerups", "pu_revive", "powerup", "dawn", ["art:wisp@gold_wisp"]],
	["powerups", "pu_light", "powerup", "night", ["art:paper_lantern"]],
	["powerups", "pu_reroll", "powerup", "spirit", ["item:object/Dice_6.png"]],
	["powerups", "pu_skip", "powerup", "blade", ["art:chevrons"]],
	["powerups", "pu_banish", "powerup", "crimson", ["art:ofuda", "art:x_mark"]],
]

## Kami: [id, camadas]; o fundo vem da cor do Kami em data/kami.json.
var _kami: Array = [
	["inari", ["art:fox"]],
	["raijin", ["code:taiko_ring", "art:bolt_s@white_bolt"]],
	["amaterasu", ["code:sun"]],
	["susanoo", ["art:wave"]],
	["tsukuyomi", ["code:moon"]],
	["hachiman", ["art:kabuto"]],
	["ebisu", ["item:food/Fish.png"]],
	["fujin", ["art:spiral"]],
	["benzaiten", ["item:object/PanFlute.png"]],
	["bishamon", ["art:pagoda"]],
	["kannon", ["art:lotus"]],
	["daikoku", ["item:object/MoneyBag.png"]],
	["jurojin", ["art:peach"]],
	["fukurokuju", ["item:object/Book.png"]],
	["okuninushi", ["item:object/Bag.png"]],
]


func _initialize() -> void:
	var made := 0
	for spec: Array in _specs:
		_save(_icon(spec[2], _element(spec[3]), spec[4]), spec[0], spec[1])
		made += 1
	var kami_colors := _kami_colors()
	for spec: Array in _kami:
		var base: Color = kami_colors.get(spec[0], Color("ff9f43"))
		var el := [base.lerp(Color.WHITE, 0.45), base.darkened(0.25), base.darkened(0.82)]
		_save(_icon("kami", el, spec[1]), "kami", spec[0])
		made += 1
	print("gen_skill_icons: %d ícones" % made)
	quit()


func _kami_colors() -> Dictionary:
	var out := {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/kami.json"))
	for row: Dictionary in data:
		out[String(row["id"])] = Color(String(row.get("color", "#ff9f43")))
	return out


func _element(name: String) -> Array:
	var e: Array = ELEMENTS[name]
	return [Color(e[0]), Color(e[1]), Color(e[2])]


func _save(img: Image, group: String, id: String) -> void:
	var dir := ProjectSettings.globalize_path(OUT_DIR + group)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/" + id + ".png")


# --- Montagem do ícone --------------------------------------------------------------------

func _icon(category: String, el: Array, layers: Array) -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_background(img, el)
	var glyph := _compose(layers)
	var at := Vector2i(3 + (INNER - glyph.get_width()) / 2, 3 + (INNER - glyph.get_height()) / 2)
	# Sombra projetada (1 px para baixo/direita) e depois a silhueta.
	_blend_tinted(img, glyph, at + Vector2i(1, 1), Color(0.02, 0.0, 0.05, 0.55), Rect2i(3, 3, INNER, INNER))
	_blend(img, glyph, at, Rect2i(3, 3, INNER, INNER))
	_frame(img, category, el)
	return img


## Empilha as camadas num quadro 18x18 (cada uma já com contorno próprio).
func _compose(layers: Array) -> Image:
	var canvas := Image.create_empty(INNER, INNER, false, Image.FORMAT_RGBA8)
	for raw: String in layers:
		var spec := raw
		var flip := spec.ends_with("|flip")
		spec = spec.trim_suffix("|flip")
		var offset := Vector2i.ZERO
		if spec.contains(">"):
			var parts := spec.split(">")
			spec = parts[0]
			var xy := parts[1].split(",")
			offset = Vector2i(int(xy[0]), int(xy[1]))
		var layer := _layer(spec)
		if flip:
			layer.flip_x()
		var at := Vector2i((INNER - layer.get_width()) / 2, (INNER - layer.get_height()) / 2) + offset
		_blend(canvas, layer, at, Rect2i(0, 0, INNER, INNER))
	return _trim(canvas)


func _layer(spec: String) -> Image:
	var kind := spec.get_slice(":", 0)
	var name := spec.get_slice(":", 1)
	match kind:
		"item":
			var img := Image.load_from_file(ProjectSettings.globalize_path(ITEMS + name))
			img.convert(Image.FORMAT_RGBA8)
			return _trim(img)
		"art":
			var recolor := {}
			if name.contains("@"):
				recolor = RECOLOR[name.get_slice("@", 1)]
				name = name.get_slice("@", 0)
			return _outline(_from_ascii(ART[name], recolor))
		"code":
			return _outline(call("_code_" + name))
	push_error("camada desconhecida " + spec)
	return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)


func _from_ascii(rows: Array, recolor: Dictionary) -> Image:
	var w := 0
	for row: String in rows:
		w = maxi(w, row.length())
	var img := Image.create_empty(w + 2, rows.size() + 2, false, Image.FORMAT_RGBA8)
	for y: int in range(rows.size()):
		var row: String = rows[y]
		for x: int in range(row.length()):
			var ch := row[x]
			if ch == ".":
				continue
			ch = String(recolor.get(ch, ch))
			img.set_pixel(x + 1, y + 1, Color(String(PAL[ch])))
	return img


## Contorno escuro de 1 px (vizinhança de 4) em volta dos pixels opacos.
func _outline(src: Image) -> Image:
	var w := src.get_width() + 2
	var h := src.get_height() + 2
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ONE)
	var dark := Color(String(PAL["K"]))
	var ring: Array[Vector2i] = []
	for y: int in range(h):
		for x: int in range(w):
			if img.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p := Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h and img.get_pixelv(p).a > 0.5:
					ring.append(Vector2i(x, y))
					break
	for p: Vector2i in ring:
		img.set_pixelv(p, dark)
	return _trim(img)


func _trim(img: Image) -> Image:
	var used := img.get_used_rect()
	if used.size.x <= 0:
		return img
	return img.get_region(used)


func _blend(dst: Image, src: Image, at: Vector2i, clip: Rect2i) -> void:
	for y: int in range(src.get_height()):
		for x: int in range(src.get_width()):
			var p := at + Vector2i(x, y)
			if not clip.has_point(p):
				continue
			var c := src.get_pixel(x, y)
			if c.a <= 0.01:
				continue
			dst.set_pixelv(p, dst.get_pixelv(p).blend(c) if c.a < 0.99 else c)


func _blend_tinted(dst: Image, src: Image, at: Vector2i, tint: Color, clip: Rect2i) -> void:
	for y: int in range(src.get_height()):
		for x: int in range(src.get_width()):
			var p := at + Vector2i(x, y)
			if clip.has_point(p) and src.get_pixel(x, y).a > 0.5:
				dst.set_pixelv(p, dst.get_pixelv(p).blend(tint))


# --- Fundo e moldura ----------------------------------------------------------------------

const BAYER := [[0.0, 0.5], [0.75, 0.25]]


## Degradê diagonal do elemento em 6 tons, pontilhado 2x2, com halo central atrás da silhueta.
func _background(img: Image, el: Array) -> void:
	var tones: Array[Color] = []
	for i: int in range(6):
		var t := i / 5.0
		tones.append((el[2] as Color).lerp(el[1], t * 2.0) if t < 0.5 else (el[1] as Color).lerp(el[0], (t - 0.5) * 2.0))
	var center := Vector2(12.0, 12.0)
	for y: int in range(3, 21):
		for x: int in range(3, 21):
			# Luz vem do alto à esquerda; halo radial suave no meio.
			var diag := 1.0 - ((x - 3) * 0.35 + (y - 3) * 0.65) / 17.0
			var halo := clampf(1.0 - Vector2(x + 0.5, y + 0.5).distance_to(center) / 9.0, 0.0, 1.0)
			var v := clampf(diag * 0.62 + halo * 0.42, 0.0, 1.0) * 4.999
			var idx := floori(v)
			# Pontilhado só na faixa estreita da transição entre tons (sem chiado).
			if v - idx > 0.82 and (x + y) % 2 == 0:
				idx += 1
			img.set_pixel(x, y, tones[clampi(idx, 0, 5)])
	# Sombra interna (embutido): topo e esquerda mais escuros, 1 px.
	for i: int in range(3, 21):
		img.set_pixel(i, 3, img.get_pixel(i, 3).darkened(0.35))
		img.set_pixel(3, i, img.get_pixel(3, i).darkened(0.35))
	# Brilho de canto: risco diagonal no alto à esquerda.
	for p: Vector2i in [Vector2i(5, 4), Vector2i(4, 5), Vector2i(6, 4), Vector2i(4, 6), Vector2i(5, 5)]:
		img.set_pixelv(p, img.get_pixelv(p).lerp(Color.WHITE, 0.45))


func _frame(img: Image, category: String, el: Array) -> void:
	var f: Array = FRAMES[category]
	var light := Color(String(f[0]))
	var mid := Color(String(f[1]))
	var dark := Color(String(f[2]))
	var inner := Color(String(f[3]))
	var outline := Color(OUTLINE)
	var chamfer := 2 if category in ["passive", "powerup", "kami"] else 1
	for y: int in range(SIZE):
		for x: int in range(SIZE):
			var ring := mini(mini(x, y), mini(SIZE - 1 - x, SIZE - 1 - y))
			if ring > 2:
				continue
			# Cantos chanfrados (transparentes).
			var cx := mini(x, SIZE - 1 - x)
			var cy := mini(y, SIZE - 1 - y)
			if cx + cy < chamfer:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if ring == 0 or cx + cy == chamfer:
				img.set_pixel(x, y, outline)
			elif ring == 1:
				# Bisel: claro no alto/esquerda, escuro embaixo/direita.
				var top_left := (y == 1 or x == 1) and not (y == SIZE - 2 or x == SIZE - 2)
				var bottom_right := (y == SIZE - 2 or x == SIZE - 2) and not (y == 1 or x == 1)
				img.set_pixel(x, y, light if top_left else (dark if bottom_right else mid))
			else:
				img.set_pixel(x, y, inner if category in ["weapon", "passive", "powerup"] else mid)
	match category:
		"evolution", "union":
			_evolved_trim(img, category == "union")
		"kami":
			_kami_trim(img)
		"passive":
			_rivets(img, Color(String(f[0])))
	# Reflexo no aro, canto alto à esquerda.
	img.set_pixel(2, 1, Color.WHITE)
	img.set_pixel(1, 2, light.lerp(Color.WHITE, 0.5))


## Evoluída: aro duplo dourado, cravos em losango nos 4 cantos e joia no topo.
func _evolved_trim(img: Image, union: bool) -> void:
	var gold := Color("f2b23a")
	var hi := Color("fff6b8")
	var deep := Color("9a5410")
	var jewel := Color("e8483a") if union else Color("52cdf0")
	var jewel_hi := Color("ffb0a0") if union else Color("c8fcff")
	var outline := Color(OUTLINE)
	# Linha interna dourada escura (segundo aro).
	for i: int in range(3, 21):
		for p: Vector2i in [Vector2i(i, 2), Vector2i(2, i), Vector2i(i, 21), Vector2i(21, i)]:
			img.set_pixelv(p, deep)
	# Cravos nos cantos: losango 3x3 sobre o aro.
	for c: Vector2i in [Vector2i(2, 2), Vector2i(21, 2), Vector2i(2, 21), Vector2i(21, 21)]:
		for d: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var p := c + d
			if p.x >= 0 and p.y >= 0 and p.x < SIZE and p.y < SIZE:
				img.set_pixelv(p, gold)
		img.set_pixelv(c, hi)
	# Joia no meio do topo e da base.
	for x: int in [11, 12]:
		img.set_pixel(x, 0, outline)
		img.set_pixel(x, 1, jewel_hi if x == 11 else jewel)
		img.set_pixel(x, 2, jewel)
		img.set_pixel(x, 22, jewel)
		img.set_pixel(x, 23, outline)
	for x: int in [10, 13]:
		img.set_pixel(x, 1, gold)
		img.set_pixel(x, 2, deep)
		img.set_pixel(x, 22, gold)
	if union:
		# União: cantos com ponto vermelho (dois deuses/armas num só).
		for c: Vector2i in [Vector2i(2, 2), Vector2i(21, 2), Vector2i(2, 21), Vector2i(21, 21)]:
			img.set_pixelv(c, jewel)


## Kami: laca vermelha com barra dourada no alto (lembra o kasagi do torii).
func _kami_trim(img: Image) -> void:
	var gold := Color("f2b23a")
	var hi := Color("fff6b8")
	for x: int in range(4, 20):
		img.set_pixel(x, 1, hi if x < 12 else gold)
	for p: Vector2i in [Vector2i(2, 2), Vector2i(21, 2), Vector2i(2, 21), Vector2i(21, 21)]:
		img.set_pixelv(p, gold)


## Passiva: rebites de bronze nos 4 cantos.
func _rivets(img: Image, color: Color) -> void:
	for p: Vector2i in [Vector2i(2, 2), Vector2i(21, 2), Vector2i(2, 21), Vector2i(21, 21)]:
		img.set_pixelv(p, color)


# --- Silhuetas desenhadas por código ------------------------------------------------------

func _canvas(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


func _c(letter: String) -> Color:
	return Color(String(PAL[letter]))


func _line(img: Image, a: Vector2i, b: Vector2i, color: Color) -> void:
	var d := b - a
	var steps := maxi(absi(d.x), absi(d.y))
	for i: int in range(steps + 1):
		var t := 0.0 if steps == 0 else float(i) / steps
		var p := Vector2i(roundi(a.x + d.x * t), roundi(a.y + d.y * t))
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
			img.set_pixelv(p, color)


func _code_fan() -> Image:
	var img := _canvas(17, 11)
	var pivot := Vector2(8.5, 10.0)
	for y: int in range(11):
		for x: int in range(17):
			var rel := Vector2(x + 0.5, y + 0.5) - pivot
			var r := rel.length()
			var ang := rad_to_deg(atan2(-rel.y, rel.x))
			if ang < 8.0 or ang > 172.0:
				continue
			var panel := floori((ang - 8.0) / 20.5)
			if r >= 4.2 and r <= 9.6:
				var col := _c("A") if panel % 2 == 0 else _c("a")
				if r > 8.7:
					col = _c("R")
				elif r < 5.0:
					col = _c("q")
				img.set_pixel(x, y, col)
			elif r < 4.2 and r > 1.0 and absf(fmod(ang - 8.0, 20.5)) < 6.0:
				img.set_pixel(x, y, _c("B"))
	img.set_pixel(8, 9, _c("G"))
	img.set_pixel(8, 10, _c("b"))
	return img


func _code_bow() -> Image:
	var img := _canvas(14, 14)
	# Arco: quarto de círculo; corda reta entre as pontas; flecha puxada atravessando.
	var center := Vector2(12.5, 12.5)
	for y: int in range(14):
		for x: int in range(14):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			if d >= 10.4 and d <= 12.0 and x < 12 and y < 12:
				var mid := absi(x - y) <= 1 and x < 6
				img.set_pixel(x, y, _c("G") if mid else (_c("B") if d < 11.3 else _c("b")))
	_line(img, Vector2i(1, 12), Vector2i(12, 1), _c("L"))
	_line(img, Vector2i(2, 2), Vector2i(11, 11), _c("S"))
	img.set_pixel(1, 1, _c("W"))
	img.set_pixel(2, 1, _c("L"))
	img.set_pixel(1, 2, _c("L"))
	for p: Vector2i in [Vector2i(11, 12), Vector2i(12, 11), Vector2i(12, 12), Vector2i(10, 12), Vector2i(12, 10)]:
		img.set_pixelv(p, _c("R"))
	return img


func _code_gold_arrow() -> Image:
	var img := _canvas(15, 15)
	_line(img, Vector2i(3, 11), Vector2i(11, 3), _c("G"))
	_line(img, Vector2i(3, 12), Vector2i(12, 3), _c("Y"))
	# Ponta.
	for p: Vector2i in [Vector2i(13, 1), Vector2i(12, 1), Vector2i(13, 2), Vector2i(11, 2), Vector2i(12, 2),
			Vector2i(10, 2), Vector2i(12, 4), Vector2i(12, 3), Vector2i(11, 3)]:
		img.set_pixelv(p, _c("L"))
	img.set_pixel(13, 1, _c("W"))
	# Penas.
	for p: Vector2i in [Vector2i(1, 11), Vector2i(2, 10), Vector2i(1, 12), Vector2i(2, 13), Vector2i(3, 14),
			Vector2i(0, 13), Vector2i(1, 14), Vector2i(2, 12)]:
		img.set_pixelv(p, _c("W"))
	for p: Vector2i in [Vector2i(4, 13), Vector2i(3, 13), Vector2i(0, 12)]:
		img.set_pixelv(p, _c("R"))
	return img


func _code_zigzag() -> Image:
	var img := _canvas(16, 13)
	var pts: Array[Vector2i] = [Vector2i(0, 9), Vector2i(4, 3), Vector2i(7, 8), Vector2i(11, 1), Vector2i(12, 6), Vector2i(15, 2)]
	for i: int in range(pts.size() - 1):
		_line(img, pts[i] + Vector2i(0, 2), pts[i + 1] + Vector2i(0, 2), _c("v"))
		_line(img, pts[i] + Vector2i(0, 1), pts[i + 1] + Vector2i(0, 1), _c("t"))
		_line(img, pts[i], pts[i + 1], _c("T"))
	for p: Vector2i in [Vector2i(4, 3), Vector2i(11, 1), Vector2i(7, 8)]:
		img.set_pixelv(p, _c("W"))
	return img


func _code_sun() -> Image:
	var img := _canvas(15, 15)
	var c := Vector2(7.5, 7.5)
	for y: int in range(15):
		for x: int in range(15):
			var rel := Vector2(x + 0.5, y + 0.5) - c
			var d := rel.length()
			if d <= 4.3:
				var col := _c("F")
				if rel.x + rel.y < -2.5:
					col = _c("W") if d > 2.0 else _c("Y")
				elif rel.x + rel.y > 2.5:
					col = _c("G")
				img.set_pixel(x, y, col)
			elif d >= 5.6 and d <= 7.4:
				var ang := fposmod(rad_to_deg(atan2(rel.y, rel.x)), 45.0)
				if ang < 9.0 or ang > 36.0:
					img.set_pixel(x, y, _c("G") if d > 6.6 else _c("F"))
	return img


func _code_sun_small() -> Image:
	var img := _canvas(9, 9)
	var c := Vector2(4.5, 4.5)
	for y: int in range(9):
		for x: int in range(9):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= 4.4:
				img.set_pixel(x, y, _c("F") if d > 2.6 else _c("W"))
	return img


func _code_moon() -> Image:
	var img := _canvas(14, 14)
	var a := Vector2(7.0, 7.0)
	var b := Vector2(10.0, 4.6)
	for y: int in range(14):
		for x: int in range(14):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(a) <= 6.6 and p.distance_to(b) > 5.4:
				var edge := p.distance_to(a) > 5.6
				img.set_pixel(x, y, _c("p") if edge and p.x + p.y > 12 else (_c("W") if p.x < 4 and p.y < 9 else _c("P")))
	return img


func _code_rosary() -> Image:
	var img := _canvas(13, 15)
	var c := Vector2(6.5, 6.0)
	for y: int in range(15):
		for x: int in range(13):
			var rel := Vector2(x + 0.5, y + 0.5) - c
			var d := rel.length()
			if d >= 4.0 and d <= 6.0:
				var seg := floori(fposmod(rad_to_deg(atan2(rel.y, rel.x)), 360.0) / 30.0)
				var col := _c("M") if seg % 2 == 0 else _c("m")
				if d < 4.6:
					col = _c("u")
				img.set_pixel(x, y, col)
	# Conta grande e borla.
	for p: Vector2i in [Vector2i(6, 11), Vector2i(5, 11), Vector2i(7, 11), Vector2i(6, 12)]:
		img.set_pixelv(p, _c("G"))
	img.set_pixel(5, 11, _c("Y"))
	for y: int in range(13, 15):
		for x: int in range(5, 8):
			img.set_pixel(x, y, _c("R"))
	return img


func _code_koban() -> Image:
	var img := _canvas(10, 14)
	var c := Vector2(5.0, 7.0)
	for y: int in range(14):
		for x: int in range(10):
			var rel := (Vector2(x + 0.5, y + 0.5) - c) / Vector2(4.9, 6.9)
			var d := rel.length()
			if d > 1.0:
				continue
			var col := _c("G")
			if d > 0.78:
				col = _c("Y") if rel.x + rel.y < 0 else _c("O")
			elif y in [4, 7, 10] and x > 2 and x < 7:
				col = _c("O")
			img.set_pixel(x, y, col)
	img.set_pixel(3, 2, _c("W"))
	return img


## Anel de taiko do Raijin: oito tamborzinhos ligados por um aro dourado.
func _code_taiko_ring() -> Image:
	var img := _canvas(17, 17)
	var c := Vector2(8.5, 8.5)
	for y: int in range(17):
		for x: int in range(17):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d >= 5.6 and d <= 6.5:
				img.set_pixel(x, y, _c("G") if y < 9 else _c("O"))
	for k: int in range(8):
		var a := deg_to_rad(22.5 + k * 45.0)
		var dc := c + Vector2(cos(a), sin(a)) * 6.0
		for y: int in range(17):
			for x: int in range(17):
				var rel := Vector2(x + 0.5, y + 0.5) - dc
				var d := rel.length()
				if d <= 2.1:
					var col := _c("R")
					if d > 1.5:
						col = _c("r")
					elif rel.x + rel.y < -0.6:
						col = _c("P")
					img.set_pixel(x, y, col)
	return img


func _code_tomoe_drum() -> Image:
	var img := _canvas(15, 15)
	var c := Vector2(7.5, 7.5)
	for y: int in range(15):
		for x: int in range(15):
			var rel := Vector2(x + 0.5, y + 0.5) - c
			var d := rel.length()
			if d > 7.3:
				continue
			var col := _c("P")
			if d > 5.9:
				col = _c("R") if rel.y < 2.0 else _c("r")
				var ang := fposmod(rad_to_deg(atan2(rel.y, rel.x)), 45.0)
				if d < 6.7 and ang > 18.0 and ang < 27.0:
					col = _c("G")
			elif d > 5.1:
				col = _c("p")
			img.set_pixel(x, y, col)
	return img


func _code_mist() -> Image:
	var img := _canvas(17, 6)
	for x: int in range(17):
		var h := 2 + int(1.5 + 1.5 * sin(x * 0.9))
		for y: int in range(6 - h, 6):
			img.set_pixel(x, y, _c("m") if (x + y) % 3 else _c("M"))
	return img


func _code_sparks() -> Image:
	var img := _canvas(16, 16)
	for p: Vector2i in [Vector2i(2, 4), Vector2i(3, 3), Vector2i(4, 4), Vector2i(3, 5), Vector2i(3, 4),
			Vector2i(12, 11), Vector2i(13, 10), Vector2i(14, 11), Vector2i(13, 12), Vector2i(13, 11)]:
		img.set_pixelv(p, _c("W") if p in [Vector2i(3, 4), Vector2i(13, 11)] else _c("T"))
	return img


func _code_slash_arc() -> Image:
	var img := _canvas(17, 17)
	var c := Vector2(2.0, 15.0)
	for y: int in range(17):
		for x: int in range(17):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d >= 13.0 and d <= 14.6:
				img.set_pixel(x, y, _c("H") if d < 13.8 else _c("R"))
	return img
