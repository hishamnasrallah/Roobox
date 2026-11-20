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

افتح البورتات: **7350/tcp** (الحسابات) و **7777/udp** (اللعب).
بالتطبيق: **SETTINGS** ← اكتب `http://IP-السيرفر:7350` ← **SAVE & CONNECT**. بعدها زر **PLAY ONLINE** بيدخلك عالسيرفر مباشرة.

> صورة `roobox-server` على ghcr.io خاصة افتراضياً: إما `docker login ghcr.io` على السيرفر، أو خليها Public من صفحة Packages.

لوحة إدارة Nakama (لاعبين، بيانات، أرقام قياسية) على بورت 7351 ومفتوحة بس محلياً:
`ssh -L 7351:127.0.0.1:7351 user@السيرفر` وبعدين افتح `http://localhost:7351`.

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
