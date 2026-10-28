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
    keys |= {f"moon.rule{n}" for n in range(1, 6)}
    keys |= {f"damage.source.{s}" for s in ("lava", "statue", "unknown")}
    keys |= {f"cosmetic.{c}" for c in ("golden_lantern", "crimson_lantern", "jade_lantern",
                                        "azure_lantern", "violet_lantern")}
    keys |= {f"licenses.cat_{c}" for c in ("all", "engine", "art", "audio", "font", "android")}
    for key in ("music_volume", "sfx_volume", "ui_volume", "joystick_mode", "joystick_side", "fps",
                "vibration", "colorblind", "reduce_flashes", "damage_numbers", "damage_sounds", "hurt_sounds", "hp_bar_below",
                "notifications"):
        keys.add(f"options.{key}")
    keys |= {"options.joystick_floating", "options.joystick_fixed", "options.side_left",
             "options.side_right", "options.fps30", "options.fps60", "options.fps120"}
    keys |= {f"statname.{s}" for s in ("max_hp", "regen", "armor", "speed", "might", "area",
             "cooldown", "amount", "duration", "magnet", "luck", "growth", "greed", "curse", "light")}
    keys |= {"levelup.reroll", "levelup.skip", "levelup.banish", "results.weapon", "results.level",
             "results.damage", "results.dps"}
    return keys


def all_keys() -> list:
    return sorted(code_keys() | data_keys())


if __name__ == "__main__":
    for key in all_keys():
        print(key)
