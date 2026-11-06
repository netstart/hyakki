# Altares do Selo e Elites com afixos (scripts/systems/altar_system.gd, elite_affixes.gd).
# Ordem: pt_BR, en, es, de, fr, ru, id, ja, ko, zh_TW, zh_CN.
# "elite.name" monta o nome do Elite com String.format: {enemy} = nome do inimigo, {affix} = o 1º
# afixo (a ordem das palavras muda por idioma); os outros afixos vêm depois de " · ".
STRINGS = {
    "elite.name": ["{enemy} {affix}", "{affix} {enemy}", "{enemy} {affix}", "{enemy} {affix}", "{enemy} {affix}", "{enemy} {affix}", "{enemy} {affix}", "{affix}{enemy}", "{affix} {enemy}", "{affix}{enemy}", "{affix}{enemy}"],
    "elite.affix.raijin": ["do Trovão", "Thunder", "del Trueno", "des Donners", "du Tonnerre", "Грома", "Guntur", "雷の", "천둥의", "雷之", "雷之"],
    "elite.affix.kitsunebi": ["da Raposa", "Foxfire", "del Zorro", "des Fuchsfeuers", "du Renard", "Лисьего огня", "Api Rubah", "狐火の", "여우불의", "狐火之", "狐火之"],
    "elite.affix.kagero": ["Miragem", "Mirage", "Espejismo", "der Fata Morgana", "Mirage", "Миража", "Fatamorgana", "陽炎の", "아지랑이의", "陽炎之", "阳炎之"],
    "elite.affix.iwa": ["da Rocha", "Boulder", "de Roca", "des Felsens", "du Roc", "Скалы", "Batu", "岩の", "바위의", "巖之", "岩之"],
    "elite.affix.kasumi": ["da Névoa", "Mist", "de la Niebla", "des Nebels", "de Brume", "Тумана", "Kabut", "霞の", "안개의", "霞之", "霞之"],
    "elite.affix.kongo": ["Diamante", "Diamond", "Diamante", "aus Diamant", "Diamant", "Алмаза", "Intan", "金剛の", "금강의", "金剛之", "金刚之"],
    "elite.affix.yomi": ["do Yomi", "Yomi", "del Yomi", "aus Yomi", "du Yomi", "Ёми", "Yomi", "黄泉の", "황천의", "黃泉之", "黄泉之"],
    "elite.affix.kaze": ["do Vento", "Gale", "del Viento", "des Windes", "du Vent", "Ветра", "Angin", "風の", "바람의", "風之", "风之"],
    "altar.locked": ["O selo não cede enquanto um chefe vive", "The seal won't break while a boss lives", "El sello no cede mientras viva un jefe", "Das Siegel hält, solange ein Boss lebt", "Le sceau tient tant qu'un boss vit", "Печать не поддаётся, пока жив босс", "Segel tak terbuka selama bos hidup", "ボスがいる間は封印が解けない", "보스가 살아 있는 동안 봉인은 풀리지 않는다", "首領存活時封印不會解開", "首领存活时封印不会解开"],
    "altar.ambush": ["Emboscada!", "Ambush!", "¡Emboscada!", "Hinterhalt!", "Embuscade !", "Засада!", "Penyergapan!", "待ち伏せだ！", "매복이다!", "伏擊！", "伏击！"],
    "altar.elite_slain": ["Selo vencido!", "Seal vanquished!", "¡Sello vencido!", "Siegel bezwungen!", "Sceau vaincu !", "Печать повержена!", "Segel ditaklukkan!", "封印を制した！", "봉인을 제압했다!", "封印已平定！", "封印已平定！"],
}
