# Roobox

لعبة 3D جماعية بستايل بلوكي (sandbox / obby) — **أندرويد أولاً** — مبنية على **Godot 4.7**.

> Blocky 3D multiplayer sandbox, Android first, built with Godot 4.7 (Mobile/Vulkan renderer + Jolt physics).

## جرّبها على تلفونك

كل `push` بيبني APK تلقائياً عن طريق GitHub Actions:

1. افتح صفحة **Releases** بالريبو ونزّل `roobox-debug.apk` من إصدار **dev-latest**
   (أو من تبويب **Actions** ← آخر run ← Artifacts).
2. افتح الملف على التلفون واسمح بـ "تثبيت تطبيقات غير معروفة".

## اللعب مع الأصحاب

- **على نفس الـ Wi-Fi:** تلفون واحد بيضغط **HOST GAME**، وبيطلعله الـ IP فوق الشاشة. الباقي بيكتبوا الـ IP وبيضغطوا **JOIN**.
- **على الإنترنت:** شغّل السيرفر المستقل على أي VPS (لازم UDP بورت 7777 مفتوح):
  ```bash
  docker run -d --restart unless-stopped -p 7777:7777/udp ghcr.io/hishamnasrallah/roobox-server:latest
  ```
  وبعدين كل اللاعبين بيكتبوا IP السيرفر وبيضغطوا JOIN.
  (أو نزّل `roobox_server.x86_64` من إصدار dev-latest وشغّله: `./roobox_server.x86_64 --headless -- --server --port 7777`)

## السيرفر الكامل (حسابات + أصدقاء + أرقام قياسية + سيرفر لعب)

على أي VPS فيه Docker (مثلاً Ubuntu من Hetzner أو DigitalOcean):

```bash
git clone https://github.com/hishamnasrallah/Roobox.git && cd Roobox/backend
cp .env.example .env && nano .env          # غيّر كلمات السر
docker compose --profile game up -d        # Nakama + Postgres + سيرفر اللعب
```

افتح البورتات: **7350/tcp** (الحسابات) و **7777-7780/udp** (سيرفر لكل لعبة).
بالتطبيق: **SETTINGS** ← اكتب `http://IP-السيرفر:7350` ← **SAVE & CONNECT**. بعدها زر **PLAY ONLINE** بيدخلك عالسيرفر مباشرة.

> صورة `roobox-server` على ghcr.io خاصة افتراضياً: إما `docker login ghcr.io` على السيرفر، أو خليها Public من صفحة Packages.

لوحة إدارة Nakama (لاعبين، بيانات، أرقام قياسية) على بورت 7351 ومفتوحة بس محلياً:
`ssh -L 7351:127.0.0.1:7351 user@السيرفر` وبعدين افتح `http://localhost:7351`.

## الألعاب (Discover)

| اللعبة | النوع | الفكرة |
|---|---|---|
| **Roobox Island** | استكشاف | جزيرة كبيرة: Obby Land، Sky Tower، Playground، متاهة، قرية |
| **Lava Rising** | نجاة | اللافا بتطلع — تسلّق البرج وضل عايش أطول وقت |
| **Color Drop** | حفلة | بيطلع لون — اركض لبلاطة من نفس اللون قبل ما يختفي الباقي |
| **Obby Rush** | obby | مراحل لا نهائية مولّدة، كل مرحلة أصعب |

كل لعبة: SOLO / PLAY ONLINE / HOST ON WI-FI / JOIN. بالألعاب الجماعية السيرفر (أو الـ Host) هو الحَكَم على توقيت الجولات.
لإضافة لعبة جديدة: كلاس يورث `Experience` (العالم) + اختيارياً `GameMode` (منطق الجولات) + سطر بـ `Catalog.ENTRIES`.

## مكتبة الألعاب (288 لعبة)

18 نوع × 16 ثيم، كلها ألعاب أصلية مولّدة من نفس صيغة المحرر. **كل نوع إله خريطتين مختلفتين بالبنية** (مش بس بالألوان) و3 مستويات صعوبة:
- **الأنواع (الخريطة أ / ب):** Obby (مستقيم / تسلّق حلزوني حوالين عمود)، Tower (درج حلزوني / برج طوابق كل طابق إله عائق وطريقة طلوع)، Parkour (عوائق / أسطح مباني)، Maze (بجدران / متاهة معلّقة فوق اللافا)، Floor is Lava (حلزون / أعمدة درج)، Coin Hunt (أرض مفتوحة / قرية بيوت)، Sky Islands (سلسلة / حلقة جزر + تاج)، Race (حلبة / نزلة من برج)، Trampoline Park (برج / ساحة)، Vanishing Path (مسار / شبكة)، Button Doors (ممر / شبكة غرف)، Water Course (برك / بحيرة)، Hangout (ديسكو / حديقة).
- **أنواع جديدة بميكانيك مختلف:** **Tycoon** (مصاري كل ثانية + أزرار شراء بتبني المصنع/المزرعة)، **Floor Fall** (البلاط بيوقع بعد ما تدوس عليه)، **Dropper** (سقوط حر بين عوائق لافا لبركة)، **Spinner Survival** (اقفز عن العصا الدوّارة)، **Button Hunt** (دوّر على أزرار مخبّاة لتفتح الجائزة).
- **الثيمات:** Meadow، Desert، Frozen، Candy، Galaxy، Jungle، Ocean، Volcano، Castle، City، Neon، Autumn، Cloud، Crystal، Farm، Ancient.
- **صور حقيقية:** كل لعبة إلها صورة 3D بتنرسم من خريطتها أول مرة بتظهر وبتنحفظ بالجهاز.
- تبويب PLAY: صف أفقي لكل نوع (بتسحبه بإصبعك) + بحث + فلترة. كل لعبة: PLAY SOLO / HOST / JOIN / **REMIX IN STUDIO**.

## Roobox Studio (اصنع لعبتك)

من تبويب **CREATE** ← **+ NEW GAME**:
- **الكاميرا:** إصبع واحد للدوران (ولمسة سريعة = استعمال الأداة)، إصبعين للزووم والتحريك، UP/DOWN للارتفاع. بالكمبيوتر: WASD + Q/E + الماوس.
- **الأدوات:** SELECT، **MOVE / SCALE / ROTATE بمقابض 3D بتسحبها**، BUILD، PAINT، DELETE، **TERRAIN** (مولّد تضاريس: تلال، جزيرة، جبال، صحرا، ثلج، وادي)، **EXPLORER** (قائمة القطع والمجموعات).
- **الشبكة والتدوير:** GRID 0.5 / 1 / 2 / 4 — TURN 15° / 45° / 90°، AIR للبناء بالهوا، MULTI لتحديد أكثر من قطعة، FOCUS.
- **الخصائص:** لون، مادة، شفافية، COLLIDE (تمشي من خلالها)، ANCHORED (تقع وتنزاح بالفيزياء)، LOCK، حركة، اسم للسكربت، نص اللافتة، GROUP / UNGROUP، COPY، DELETE، **UNDO + REDO**.
- **القطع:** قطع أساسية (مكعب، بلوك، لوح، جدار، عمود، Wedge، **Corner Wedge**، درج، مخروط، كرة، اسطوانة، **Truss** بتتسلّقه) + قطع لعب (Spawn، Checkpoint، Finish، لافا، أشواك، Jump/Speed pad، حزام، بوابة، عملة، سلّم) + طبيعة (مي، شجرة، لافتة) + مؤثرات (ضوء، **نار، دخان، لمعة**).
- **MODELS:** 20 نموذج جاهز (بيت، برج، سور قلعة، جسر، سياج، عمود إنارة، أشجار، صخور، طاولة، سرير، كارت، قوس، نافورة، برج مراقبة، نار مخيم، بسطة، علم، مجموعة أوبي) بتنحط كمجموعة وحدة.
- **TEST** بيشغّل لعبتك فوراً، **SAVE** على الجهاز، **PUBLISH** بينشرها بـ COMMUNITY.
- اختصارات الكمبيوتر: Ctrl+Z / Ctrl+Y، Ctrl+D نسخ، Ctrl+G تجميع، Del حذف، F تركيز، R تدوير، 1-5 للأدوات.

## السكربتات (RooScript)

بالمحرر: سمّي القطع (SELECT ← name) وبعدين **SCRIPT**. اللغة بأسلوب Lua، وفي قوالب جاهزة (DOOR، VANISH، SCORE، DISCO، BOOST، ELEVATOR):

```lua
on_touch("button", function(player)
  local door = world.find("door")
  door:set_solid(false)
  ui.message(player.name .. " opened the door!", 2)
  after(5, function() door:set_solid(true) end)
end)
```

- **أحداث:** `on_start` · `on_touch(name, fn(player, part))` (part = القطعة بالضبط اللي انلمست) · `after(sec, fn)` · `every(sec, fn)` · `cancel(id)` · `time()`
- **القطع:** `world.find(name)` ← `set_color` · `set_visible` · `set_solid` · `move_to` · `move_by` · `position` · `destroy`
- **اللاعب:** `teleport` · `kill` · `give_coins` · `set_speed` · `set_jump` · `message` · `position` · `player.name`
- **الواجهة والنقاط:** `ui.message` · `ui.status` · `score.add/set/get`
- **اللاعبين والحفظ:** `on_join(fn(player))` · `on_leave(fn(player))` · `player:set_data(key, v)` · `player:get_data(key)` (بتنحفظ بين الزيارات)
- **لوحة النقاط والبادجات:** `player:set_stat(name, v)` · `player:add_stat(name, n)` · `player:get_stat(name)` (لحد 3 أعمدة بالزاوية) · `player:award_badge(name)`
- **اللغة:** متغيرات، جداول، دوال وclosures، `if/while/repeat/for/for-in`، `pairs/ipairs`، مكتبات `math/string/table`.
- السكربت بيشتغل عند الـ Host (أو بالـ Solo) وتأثيره على العالم بيوصل لكل اللاعبين. فيه حد للخطوات بيوقف أي حلقة لا نهائية، وأخطاء بأرقام الأسطر.

## داخل اللعبة

- **EMOTE:** 7 حركات (WAVE، DANCE، CHEER، POINT، CLAP، SIT، LAUGH) بتبيّن لكل اللاعبين، أو اكتب `/e dance` بالشات. **RESET** بيرجعك لآخر checkpoint.
- **فقاعات كلام** فوق راس اللي بيحكي، **لوحة نقاط** لما اللعبة بتستعملها، و**بادجات** (شوفها بتبويب AVATAR).
- **أدوات:** Speed Coil (أسرع) و Gravity Coil (قفز أعلى) لحد ما تموت.
- **فرق:** حط TEAM SPAWN بلونين أو أكتر بالـ Studio، واللاعبين بيتوزعوا على الفرق (والسكربت بيعرف `player.team`).
- **مقاعد وكارتات:** امشي على الكرسي لتقعد، وعالكارت لتسوقه (الجويستك للسواقة، JUMP لتنزل).
- **الأصدقاء:** بتشوف شو عم يلعبوا، وزر **JOIN** بيدخلك معهم.
- **رقابة أبوية** بالإعدادات: إيقاف الشات / اللعب أونلاين / النشر / الأصدقاء، مقفولة بـ PIN.
- تبويب PLAY: **كمّل اللعب** و**المفضّلة** (زر FAVORITE بصفحة كل لعبة).
- قائمة الفروق الكاملة مع روبلوكس وخطة تطويرها: [docs/ROBLOX_GAP.md](docs/ROBLOX_GAP.md).

## العالم

جزيرة كبيرة فيها ساحة spawn و 4 بوابات:
- **OBBY LAND** (شمال): مسار عوائق فوق البحر — منصات متحركة، عمود دوّار، قافزة، لافا، برج حلزوني.
- **SKY TOWER** (شرق): برج 60 متر، checkpoint كل 15 متر.
- **PLAYGROUND** (غرب): trampolines، هرم، منحدر وزحليقة، متاهة.
- **VILLAGE** (جنوب): بيوت بتقدر تدخلها وتطلع على سطوحها، بحيرة وجسر.
- غابات وتلال وعملات بكل مكان. زر **HOME** بيرجعك عالساحة.

## التحكم

| أندرويد | كمبيوتر |
|---|---|
| جويستك عائم (النص الشمال من الشاشة) | WASD / الأسهم |
| زر القفز (تحت يمين) — اضغط مطوّل لقفزة أعلى | Space |
| اسحب بالنص اليمين لتدوير الكاميرا | اسحب بالماوس |
| إصبعين (pinch) للزووم | عجلة الماوس |

## التقنيات

| الطبقة | التقنية |
|---|---|
| المحرك | Godot 4.7 — Mobile renderer (Vulkan) مع fallback لـ OpenGL ES 3 |
| الفيزياء | Jolt Physics + physics interpolation (حركة ناعمة بأي FPS) |
| الشخصية | `CharacterBody3D`: coyote time، jump buffer، قفزة متغيرة، منصات متحركة |
| الأنيميشن | أنيميشن إجرائي (procedural): idle/walk/run/jump/fall + squash & stretch + ميلان |
| الرسوم | PBR، ظلال ناعمة، glow، fog، tonemapping، كل شي procedural (APK صغير) |
| العالم الكبير | `WorldBuilder`: آلاف البلوكات بتتجمّع بـ MultiMesh مقسّمة chunks → draw calls قليلة |
| الملتي بلاير | ENet (UDP): Host على الـ Wi-Fi / سيرفر مستقل headless، interpolation للاعبين، شات |
| الأصوات | مولّدة بالكود (procedural) — بدون ملفات صوت |
| الحسابات | Nakama + Postgres: تسجيل بالجهاز، أصدقاء، حفظ سحابي، أرقام قياسية، anti-cheat بسيط |
| CI | GitHub Actions: smoke test + اختبار لمس + اختبار ملتي بلاير (سيرفر + 2 لاعبين) + APK + Docker image للسيرفر |

## هيكل المشروع

```
game/                      مشروع Godot
  project.godot
  export_presets.cfg       إعدادات تصدير أندرويد
  scenes/main.tscn
  scripts/
    autoload/game.gd       حالة اللعبة + البروفايل + توحيد الإدخال
    autoload/network.gd    الملتي بلاير (host / join / dedicated server)
    autoload/sfx.gd        الأصوات المولّدة
    world/world.gd         العالم كامل (الجزيرة والمناطق)
    world/world_builder.gd تجميع البلوكات لأداء عالي
    player/player.gd       الفيزياء والحركة
    player/avatar.gd       الشخصية البلوكية + الأنيميشن
    player/remote_player.gd اللاعبين التانيين (interpolation)
    camera/camera_rig.gd   كاميرا third-person مع تفادي الجدران
    level/                 عناصر المرحلة (منصات، عملات، checkpoints، ...)
    ui/                    القائمة الرئيسية، الواجهة، أزرار اللمس، الشات
    debug/                 اختبارات CI الآلية
    fx/fx.gd               مواد + particles
    online/                Nakama REST client + خدمات الحساب
    experiences/           الألعاب: Experience + GameMode + Catalog (+ ugc.gd لألعاب الناس)
    studio/                المحرر (studio.gd) + صيغة الألعاب (level.gd)
    scripting/             مفسّر RooScript + ScriptHost + القوالب
    avatar/                قطع متجر الأفاتار
    library/               مولّد مكتبة الـ 288 لعبة
server/Dockerfile          صورة السيرفر المستقل
backend/                   docker compose (Nakama + Postgres + game) + Lua modules
docs/ROADMAP.md            خطة المراحل
```

## التطوير محلياً

1. نزّل [Godot 4.7](https://godotengine.org/download) (النسخة العادية، مش .NET).
2. افتح `game/project.godot` واضغط F5.
3. للتصدير لأندرويد من جهازك: Editor ← Manage Export Templates، وحدد مسار Android SDK من Editor Settings.

## ملاحظة عن الاسم

`Roobox` اسم مؤقت للمشروع. قبل النشر على Google Play لازم نختار اسم وهوية أصلية مختلفة بوضوح عن أي علامة تجارية موجودة.
