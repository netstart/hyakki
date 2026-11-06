"""Lista todas as chaves de texto que o jogo usa (plano 7.7.4).

- chaves literais em tr("...") e TranslationServer.translate("...") no código;
- chaves derivadas dos dados (weapon.<id>.name, enemy.<id>.lore, ...).
Uso: python -I tools/i18n_keys.py  → imprime uma chave por linha.
Também é importado por tools/build_i18n.py e pelos testes.
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
LITERAL = re.compile(r'(?:\btr|TranslationServer\.translate)\(\s*"([a-z0-9_.]+)"\s*\)')


def data(name: str) -> list:
    return json.loads((ROOT / "data" / f"{name}.json").read_text(encoding="utf-8"))


def code_keys() -> set:
    keys = set()
    for path in (ROOT / "scripts").rglob("*.gd"):
        for match in LITERAL.finditer(path.read_text(encoding="utf-8")):
            keys.add(match.group(1))
    return keys


def data_keys() -> set:
    keys = set()
    for w in data("weapons"):
        keys |= {f"weapon.{w['id']}.name", f"weapon.{w['id']}.desc"}
        for level in w.get("levels", []):
            keys |= {f"delta.{k}" for k in level}
    for p in data("passives"):
        keys.add(f"passive.{p['id']}.name")
        keys |= {f"stat.{k}" for k in p["per_level"]}
    for e in data("enemies"):
        if e.get("codex", True) and e.get("archetype") != "prop":
            keys |= {f"enemy.{e['id']}.name", f"enemy.{e['id']}.lore"}
    for b in data("bosses"):
        keys |= {f"boss.{b['id']}.name", f"boss.{b['id']}.line", f"boss.{b['id']}.lore"}
        for n in range(1, len(b.get("phases", []))):
            keys.add(f"boss.{b['id']}.phase{n}")
    for h in data("heroes"):
        hid = h["id"]
        keys |= {f"hero.{hid}.name", f"hero.{hid}.role", f"hero.{hid}.story", f"hero.{hid}.bonus",
                 f"ultimate.{h['ultimate']['type']}.name", f"ultimate.{h['ultimate']['type']}.desc"}
        keys |= {f"stat.{k}" for k in h.get("modifiers", {})}
    for k in data("kami"):
        keys |= {f"kami.{k['id']}.name", f"kami.{k['id']}.domain"}
        if "special" in k:
            keys |= {f"kami.{k['id']}.special", f"kami.{k['id']}.cost"}
        keys |= {f"stat.{s}" for s in k.get("blessing", {})} | {f"stat.{s}" for s in k.get("cost", {})}
    for p in data("powerups"):
        keys |= {f"powerup.{p['id']}.name", f"stat.{p['stat']}"}
    for a in data("achievements"):
        keys |= {f"achievement.{a['id']}.name", f"achievement.{a['id']}.desc"}
    # Missões do Santuário: modelos por tipo de condição (MissionBook.title/description) e categorias.
    for m in data("missions"):
        kind = m["condition"]["type"]
        keys |= {f"mission.{kind}.name", f"mission.{kind}.desc", f"mission.cat.{m['cat']}"}
    keys |= {f"mission.cat.{c}" for c in ("stages", "heroes", "weapons", "bosses", "lantern", "kami",
                                          "endless", "kills", "altars", "daily", "collection")}
    keys |= ability_keys()
    for i in data("items"):
        keys.add(f"item.{i['id']}.name")
    for s in data("shop"):
        keys.add(f"shop.{s['id']}.name")
    for s in data("stages"):
        keys |= {f"stage.{s['id']}.{x}" for x in ("name", "desc", "opening", "dawn", "region", "journey")}
        if "otherworld" in s:
            keys.add(f"realm.{s['id']}.name")
    for story in data("story"):
        keys |= {p["text"] for p in story["panels"]}
    hero_ids = [h["id"] for h in data("heroes")]
    for script in data("dialogues").values():
        for line in script["lines"]:
            if line["who"] == "hero":
                keys |= {f"{line['key']}.{hid}" for hid in hero_ids}
            else:
                keys.add(line["key"])
    # Dicas 心得 (data/tips.json): as escritas e as categorias; os modelos das geradas são literais
    # em scripts/systems/tip_book.gd (TipBook.GEN_*).
    tips = json.loads((ROOT / "data" / "tips.json").read_text(encoding="utf-8"))
    keys |= {f"tip.{t['id']}" for t in tips["tips"]}
    keys |= {f"tip.cat.{c}" for c in tips["categories"]}
    keys |= {"tip.gen.evolution", "tip.gen.union", "tip.gen.shared", "tip.gen.unlock_weapon",
             "tip.gen.unlock_passive", "tip.gen.missed"}
    keys |= {f"moon.rule{n}" for n in range(1, 6)}
    keys |= {f"damage.source.{s}" for s in ("lava", "statue", "unknown")}
    keys |= {f"cosmetic.{c}" for c in ("golden_lantern", "crimson_lantern", "jade_lantern",
                                        "azure_lantern", "violet_lantern")}
    keys |= {f"licenses.cat_{c}" for c in ("all", "engine", "art", "audio", "font", "android")}
    for key in ("music_volume", "sfx_volume", "ui_volume", "joystick_mode", "joystick_side", "fps",
                "vibration", "colorblind", "reduce_flashes", "damage_numbers", "damage_sounds", "hurt_sounds", "hp_bar_below",
                "notifications", "dialogues_always"):
        keys.add(f"options.{key}")
    keys |= {"options.joystick_floating", "options.joystick_fixed", "options.side_left",
             "options.side_right", "options.fps30", "options.fps60", "options.fps120"}
    keys |= {f"statname.{s}" for s in ("max_hp", "regen", "armor", "speed", "might", "area",
             "cooldown", "amount", "duration", "magnet", "luck", "growth", "greed", "curse", "light")}
    keys |= {"levelup.reroll", "levelup.skip", "levelup.banish", "results.weapon", "results.level",
             "results.damage", "results.dps"}
    return keys


# Habilidades dos guardiões (.ai/04-habilidades-dos-guardioes.md): IDs fixos por herói
# (energia, habilidades 1-3). Com data/abilities.json presente, os IDs vêm de lá.
ABILITY_IDS = {
    "aki": ("order_flame", ("dawn_step", "lantern_wall", "century_flame")),
    "kenta": ("shadow", ("shadow_step", "kawarimi", "makibishi")),
    "hana": ("prayer", ("harae", "kekkai", "grandmother_seal")),
    "goro": ("penance", ("diamond_body", "shakujo", "master_mantra")),
    "rin": ("focus", ("hamaya", "hunting_trap", "swallow_leap")),
    "tora": ("forge_heat", ("anvil_hammer", "chain_pull", "quench")),
    "yuki": ("oni_blood", ("oni_claw", "oni_roar", "onikiri_whirl")),
}
# Textos da UI e do capítulo do Guia das habilidades; ficam aqui até o código usá-los em tr("...")
# (aí a busca literal já os encontra e esta lista pode sair).
ABILITY_UI_KEYS = (
    "ability.locked", "ability.no_energy", "ability.cooldown", "ability.cost", "ability.level_req",
    "ability.blood_price", "heroes.abilities_label", "heroes.energy_label", "tutorial.abilities",
    "guide.ch.abilities", "guide.abilities.intro", "guide.abilities.unlock_h", "guide.abilities.unlock",
    "guide.abilities.energy_h", "guide.abilities.energy", "guide.abilities.heroes_h", "guide.abilities.heroes",
    "guide.abilities.hero_line", "guide.abilities.ability_line", "guide.abilities.blood",
    "guide.abilities.unknown", "guide.abilities.keys_h", "guide.abilities.keys", "guide.abilities.hint",
    "guide.link.heroes",
)


def ability_keys() -> set:
    table = {h: (e, list(a)) for h, (e, a) in ABILITY_IDS.items()}
    path = ROOT / "data" / "abilities.json"
    if path.exists():
        raw = json.loads(path.read_text(encoding="utf-8"))
        heroes = raw.get("heroes", raw) if isinstance(raw, dict) else {h["id"]: h for h in raw}
        table = {}
        for hid, h in heroes.items():
            if isinstance(h, dict) and "energy" in h:
                energy = h["energy"]["id"] if isinstance(h["energy"], dict) else h["energy"]
                table[hid] = (energy, [a["id"] for a in h.get("abilities", [])])
    keys = set(ABILITY_UI_KEYS)
    for energy, abilities in table.values():
        keys |= {f"energy.{energy}.name", f"energy.{energy}.desc"}
        keys |= {f"ability.{a}.{x}" for a in abilities for x in ("name", "desc")}
    return keys


def all_keys() -> list:
    return sorted(code_keys() | data_keys())


if __name__ == "__main__":
    for key in all_keys():
        print(key)
