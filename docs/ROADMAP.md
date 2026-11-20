# Roadmap

## المرحلة 1 — الأساس (✅ الحالية)
- [x] مشروع Godot 4.7 بإعدادات موبايل (Vulkan Mobile، Jolt، interpolation، ETC2/ASTC)
- [x] شخصية بلوكية أصلية + أنيميشن إجرائي ناعم
- [x] تحكم لمس: جويستك عائم، زر قفز، سحب للكاميرا، pinch zoom
- [x] كاميرا third-person مع تفادي الجدران و FOV ديناميكي
- [x] مرحلة obby كاملة: منصات متحركة، عمود دوّار، jump pad، لافا، kill bricks، checkpoints، عملات، نهاية
- [x] CI: smoke test + APK تلقائي + إصدار dev-latest

## المرحلة 2 — الملتي بلاير
- [ ] سيرفر Godot headless (نفس الكود) — server-authoritative
- [ ] ENet/WebSocket، client prediction + reconciliation + interpolation
- [ ] أسماء فوق الراس، شات، emotes
- [ ] Docker image للسيرفر

## المرحلة 3 — الحسابات والمنصة
- [ ] Nakama (حسابات، أصدقاء، matchmaking، تخزين)
- [ ] تخصيص الأفاتار (ألوان، قبعات، إكسسوارات)
- [ ] صفحة استكشاف الألعاب (Discover)

## المرحلة 4 — المحرر (Studio)
- [ ] بناء عوالم داخل التطبيق: بلوكات، أشكال، ألوان، مواد
- [ ] حفظ/نشر العالم (JSON مضغوط) ومشاركته
- [ ] نسخ / تدوير / تكبير، snapping

## المرحلة 5 — السكربتات
- [ ] Luau مدمج (GDExtension) بـ sandbox آمن
- [ ] API: أحداث، عناصر، UI، تخزين بيانات اللاعب

## المرحلة 6 — النشر
- [ ] هوية واسم نهائي، أيقونات، splash
- [ ] release keystore + AAB لـ Google Play
- [ ] تحليلات و crash reporting
