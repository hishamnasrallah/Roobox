# Roobox

لعبة 3D جماعية بستايل بلوكي (sandbox / obby) — **أندرويد أولاً** — مبنية على **Godot 4.7**.

> Blocky 3D multiplayer sandbox, Android first, built with Godot 4.7 (Mobile/Vulkan renderer + Jolt physics).

## جرّبها على تلفونك

كل `push` بيبني APK تلقائياً عن طريق GitHub Actions:

1. افتح صفحة **Releases** بالريبو ونزّل `roobox-debug.apk` من إصدار **dev-latest**
   (أو من تبويب **Actions** ← آخر run ← Artifacts).
2. افتح الملف على التلفون واسمح بـ "تثبيت تطبيقات غير معروفة".

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
| CI | GitHub Actions + `barichello/godot-ci` → smoke test + APK |

## هيكل المشروع

```
game/                      مشروع Godot
  project.godot
  export_presets.cfg       إعدادات تصدير أندرويد
  scenes/main.tscn
  scripts/
    autoload/game.gd       حالة اللعبة + توحيد الإدخال (لمس/كيبورد/يد تحكم)
    player/player.gd       الفيزياء والحركة
    player/avatar.gd       الشخصية البلوكية + الأنيميشن
    camera/camera_rig.gd   كاميرا third-person مع تفادي الجدران
    level/                 عناصر المرحلة (منصات، عملات، checkpoints، ...)
    ui/                    الواجهة وأزرار اللمس
    fx/fx.gd               مواد + particles
docs/ROADMAP.md            خطة المراحل
```

## التطوير محلياً

1. نزّل [Godot 4.7](https://godotengine.org/download) (النسخة العادية، مش .NET).
2. افتح `game/project.godot` واضغط F5.
3. للتصدير لأندرويد من جهازك: Editor ← Manage Export Templates، وحدد مسار Android SDK من Editor Settings.

## ملاحظة عن الاسم

`Roobox` اسم مؤقت للمشروع. قبل النشر على Google Play لازم نختار اسم وهوية أصلية مختلفة بوضوح عن أي علامة تجارية موجودة.
