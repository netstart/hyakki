# Omikuji do baú (scripts/systems/omikuji.gd, scripts/ui/chest_panel.gd) e a opção de animação
# curta (scripts/app/screens/options_screen.gd).
# Ordem: pt_BR, en, es, de, fr, ru, id, ja, ko, zh_TW, zh_CN.
# Leitura: romaji nos idiomas latinos, kana/hangul/cirílico nos outros; zh lê o kanji direto,
# então a leitura vira "吉籤" (o papel da sorte). Curtas: cabem no palco mais estreito (172 px).
STRINGS = {
    "omikuji.kichi": ["Kichi", "Kichi", "Kichi", "Kichi", "Kichi", "Кити", "Kichi", "きち", "길", "吉籤", "吉签"],
    "omikuji.chukichi": ["Chūkichi", "Chūkichi", "Chūkichi", "Chūkichi", "Chūkichi", "Тюкити", "Chūkichi", "ちゅうきち", "중길", "中吉籤", "中吉签"],
    "omikuji.daikichi": ["Daikichi", "Daikichi", "Daikichi", "Daikichi", "Daikichi", "Дайкити", "Daikichi", "だいきち", "대길", "大吉籤", "大吉签"],
    "omikuji.kyo": ["Kyō", "Kyō", "Kyō", "Kyō", "Kyō", "Кё", "Kyō", "きょう", "흉", "凶籤", "凶签"],
    "omikuji.kichi_meaning": ["Boa sorte", "Good luck", "Buena suerte", "Glück", "Bonne fortune", "Удача", "Untung", "よい運", "좋은 운", "好運", "好运"],
    "omikuji.chukichi_meaning": ["Ótima sorte", "Great luck", "Gran suerte", "Großes Glück", "Grande fortune", "Большая удача", "Untung besar", "なかなかの運", "꽤 좋은 운", "不錯的運氣", "不错的运气"],
    "omikuji.daikichi_meaning": ["Sorte grande!", "Excellent luck!", "¡Suerte máxima!", "Höchstes Glück!", "Fortune suprême !", "Великая удача!", "Sangat beruntung!", "最高の運！", "최고의 운!", "大好運！", "大好运！"],
    "omikuji.kyo_meaning": ["Azar! Amarre no galho", "Bad luck! Tie it up", "¡Mala suerte! Átala", "Pech! An den Ast", "Malchance ! Nouez-la", "Неудача! Привяжи", "Sial! Ikat di dahan", "枝に結んで厄払い", "가지에 묶어 액땜", "綁在樹枝上化解", "绑在树枝上化解"],
    "options.chest_short": ["Animação curta do baú", "Short chest animation", "Animación corta del cofre", "Kurze Truhenanimation", "Animation courte du coffre", "Короткая анимация сундука", "Animasi peti singkat", "宝箱の演出を短く", "짧은 상자 연출", "縮短寶箱動畫", "缩短宝箱动画"],
}
