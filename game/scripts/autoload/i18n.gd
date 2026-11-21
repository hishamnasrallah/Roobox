extends Node
## Arabic / English UI. English strings are the keys; Arabic comes from
## the table below via Godot's TranslationServer, so most Controls
## translate themselves. Registered as the `I18n` autoload.

const AR: Dictionary = {
	# Tabs & menu
	"PLAY": "العب", "CREATE": "اصنع", "AVATAR": "الشخصية", "FRIENDS": "الأصدقاء",
	"RECORDS": "الأرقام القياسية", "SETTINGS": "الإعدادات", "Discover": "اكتشف",
	"Game library": "مكتبة الألعاب", "Community games": "ألعاب المجتمع", "Search games...": "ابحث عن لعبة...",
	"ALL": "الكل", "SHOW MORE": "عرض المزيد", "< ALL GAMES": "< كل الألعاب", "%d games": "%d لعبة",
	"PLAY SOLO": "العب لوحدك", "PLAY ONLINE": "العب أونلاين", "HOST ON WI-FI": "استضف على الواي فاي",
	"JOIN": "انضم", "REMIX IN STUDIO": "عدّلها بالاستوديو", "HOST": "استضف", "EDIT": "تعديل", "DELETE": "حذف",
	"Host IP  e.g. 192.168.1.5": "IP المستضيف مثلاً 192.168.1.5",
	"Online play needs an account server (SETTINGS).": "اللعب أونلاين بحاجة لسيرفر حسابات (الإعدادات).",
	"REMIX copies this game into your CREATE list so you can change anything.": "التعديل بينسخ اللعبة لقائمة ألعابك لتغيّر فيها اللي بدك.",
	"Type: %s   -   Theme: %s": "النوع: %s   -   الثيم: %s",
	"Your best: %ds survived": "أفضل نتيجة: %d ثانية", "Your best: %d rounds": "أفضل نتيجة: %d جولة",
	"Your best: stage %d": "أفضل نتيجة: المرحلة %d", "Your best:  ": "أفضل أوقاتك:  ",
	"Coins: %d": "العملات: %d", "Coins collected: %d": "العملات المجمّعة: %d",
	# Avatar
	"Your name": "اسمك", "Shirt": "القميص", "Pants": "البنطلون", "Skin": "البشرة",
	"Avatar shop": "متجر الشخصية", "DAILY REWARD +%d": "المكافأة اليومية +%d",
	"Collect coins in any game to buy items. Tap an item you own to wear or remove it.": "اجمع عملات بأي لعبة واشترِ قطع. اضغط على قطعة عندك لتلبسها أو تشلحها.",
	"WEARING": "لابسها", "OWNED - tap to wear": "عندك - اضغط لتلبسها", "%d coins": "%d عملة",
	"You bought %s!": "اشتريت %s!", "Daily reward: +%d coins!": "المكافأة اليومية: +%d عملة!",
	# Create
	"Roobox Studio": "استوديو روبوكس", "+ NEW GAME": "+ لعبة جديدة", "Your games": "ألعابك",
	"Your games will appear here.": "ألعابك رح تظهر هون.",
	"Build your own game with blocks, ramps, lava, jump pads, coins and a finish line. Test it, then publish it for everyone.": "ابنِ لعبتك بالبلوكات والمنحدرات واللافا والقافزات والعملات وخط النهاية. جرّبها وبعدين انشرها للكل.",
	# Friends / records / settings
	"Friends need an account server. Open SETTINGS and connect first.": "الأصدقاء بحاجة لسيرفر حسابات. افتح الإعدادات واتصل أول.",
	"ADD": "أضف", "ACCEPT": "قبول", "REMOVE": "إزالة", "friend's username": "اسم مستخدم صديقك",
	"No friends yet - add someone by username!": "ما عندك أصدقاء لسا - أضف حدا باسم المستخدم!",
	"Your best: %s": "أفضل نتيجة: %s", "Loading world records...": "عم يحمّل الأرقام العالمية...",
	"Connect an account server to see world records.": "اتصل بسيرفر حسابات لتشوف الأرقام العالمية.",
	"No records yet - be the first!": "ما في أرقام لسا - كون الأول!",
	"SAVE & CONNECT": "احفظ واتصل", "USE AS GUEST": "العب كضيف", "Server key": "مفتاح السيرفر",
	"Language": "اللغة", "Camera sensitivity": "حساسية الكاميرا", "Graphics": "الرسوم",
	"Sound volume": "مستوى الصوت", "Show FPS": "إظهار FPS", "LOW": "منخفضة", "MEDIUM": "متوسطة", "HIGH": "عالية",
	"ON": "تشغيل", "OFF": "إيقاف", "Account": "الحساب",
	# HUD
	"CHAT": "دردشة", "HOME": "البداية", "MENU": "القائمة", "GO!": "انطلق!", "CHECKPOINT!": "نقطة حفظ!",
	"YOU WIN!": "فزت!", "COURSE CLEAR!": "خلّصت المسار!", "BACK TO SPAWN": "ارجع للبداية",
	"KEEP EXPLORING": "كمّل استكشاف", "PLAYERS": "اللاعبين", "MUTE": "كتم", "UNMUTE": "إلغاء الكتم",
	"REPORT": "تبليغ", "NEXT": "التالي",
	"Move with the joystick on the left side of the screen.": "تحرّك بالجويستك على يسار الشاشة.",
	"Tap the arrow button to jump. Hold it to jump higher.": "اضغط زر السهم لتنط. اضغط مطوّل لتنط أعلى.",
	"Drag on the right side to look around. Pinch to zoom.": "اسحب على يمين الشاشة لتدوّر الكاميرا. قرّب وبعّد بإصبعين.",
	"Press HOME to go back to the start. Have fun!": "اضغط البداية لترجع لنقطة الانطلاق. استمتع!", "Graphics lowered for smoother play": "خففنا الرسوم ليصير اللعب أنعم", "Report sent - thank you": "انبعت التبليغ - شكراً", "Player muted": "انكتم اللاعب",
	"Chat is off (SETTINGS)": "الدردشة مقفلة (الإعدادات)", "Chat with other players": "الدردشة مع اللاعبين",
	"You are playing alone. HOST or JOIN to play with friends.": "عم تلعب لحالك. استضف أو انضم لتلعب مع أصحابك.", "DISCONNECTED": "انقطع الاتصال", "Say something...": "اكتب شي...",
	# Studio
	"UNDO": "تراجع", "SAVE": "حفظ", "SCRIPT": "سكربت", "TEST": "جرّب", "PUBLISH": "انشر", "EXIT": "خروج",
	"BUILD": "بناء", "SELECT": "تحديد", "PAINT": "تلوين", "ROTATE": "تدوير", "AIR": "هوا", "UP": "فوق", "DOWN": "تحت",
	"COLORS": "ألوان", "MATERIAL": "مواد", "COPY": "نسخ", "SET": "تعيين", "TEXT": "نص",
	"CHECK": "فحص", "CLEAR": "مسح", "DONE": "تم",
	# Genres & themes
	"Obby": "أوبي", "Tower": "برج", "Parkour": "باركور", "Maze": "متاهة", "Floor is Lava": "الأرض لافا",
	"Coin Hunt": "صيد العملات", "Sky Islands": "جزر السما", "Race": "سباق", "Trampoline Park": "حديقة الترامبولين",
	"Vanishing Path": "الطريق المختفي", "Button Doors": "أبواب وأزرار", "Water Course": "مسار المي", "Hangout": "تجمّع",
	"Meadow": "المرج", "Desert": "الصحراء", "Frozen": "الجليد", "Candy": "الحلويات", "Galaxy": "المجرة",
	"Jungle": "الغابة", "Ocean": "المحيط", "Volcano": "البركان", "Castle": "القلعة", "City": "المدينة",
	"Neon": "النيون", "Autumn": "الخريف", "Cloud": "الغيوم", "Crystal": "الكريستال", "Farm": "المزرعة", "Ancient": "الآثار",
	"Roobox Island": "جزيرة روبوكس", "Lava Rising": "اللافا الطالعة", "Color Drop": "سقوط الألوان", "Obby Rush": "أوبي بلا نهاية",
}

var language: String = "en"


func _ready() -> void:
	var t := Translation.new()
	t.locale = "ar"
	for k: String in AR:
		t.add_message(k, AR[k])
	TranslationServer.add_translation(t)


func set_language(lang: String) -> void:
	language = "ar" if lang == "ar" else "en"
	TranslationServer.set_locale(language)


func is_ar() -> bool:
	return language == "ar"


## Translate a key (also for strings built in code).
func t(key: String) -> String:
	return TranslationServer.translate(key) if language == "ar" else key


## Game title for the library: "Theme Genre" (EN) / "Genre Theme" (AR).
func game_title(theme_title: String, genre_title: String) -> String:
	if language == "ar":
		return "%s %s" % [t(genre_title), t(theme_title)]
	return "%s %s" % [theme_title, genre_title]
