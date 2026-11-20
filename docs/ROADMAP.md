# Roadmap

## المرحلة 1 — الأساس (✅ الحالية)
- [x] مشروع Godot 4.7 بإعدادات موبايل (Vulkan Mobile، Jolt، interpolation، ETC2/ASTC)
- [x] شخصية بلوكية أصلية + أنيميشن إجرائي ناعم
- [x] تحكم لمس: جويستك عائم، زر قفز، سحب للكاميرا، pinch zoom
- [x] كاميرا third-person مع تفادي الجدران و FOV ديناميكي
- [x] مرحلة obby كاملة: منصات متحركة، عمود دوّار، jump pad، لافا، kill bricks، checkpoints، عملات، نهاية
- [x] CI: smoke test + APK تلقائي + إصدار dev-latest

## المرحلة 1.5 — عالم كبير + شكل وأصوات (✅)
- [x] جزيرة كبيرة + 4 مناطق + بوابات + زر HOME
- [x] MultiMesh batching للأداء
- [x] أصوات procedural، مواد بلاستيك، قائمة رئيسية وتخصيص ألوان

## المرحلة 2 — الملتي بلاير (✅ النسخة الأولى)
- [x] سيرفر Godot headless (نفس الكود) + Docker image
- [x] Host على الـ Wi-Fi / Join بالـ IP
- [x] interpolation للاعبين التانيين، أسماء فوق الراس، شات
- [ ] تحقق أقوى على السيرفر (anti-cheat للسرعة/التليبورت)
- [ ] emotes، قائمة لاعبين، تصادم بين اللاعبين
- [ ] سيرفرات متعددة + matchmaking

## المرحلة 3 — الحسابات (✅ النسخة الأولى)
- [x] Nakama + Postgres بـ docker compose واحد
- [x] تسجيل تلقائي بالجهاز، username فريد، اسم عرض
- [x] حفظ سحابي (العملات، أفضل الأوقات، الأفاتار)
- [x] أصدقاء (إضافة بالـ username، قبول، حذف، online/offline)
- [x] أرقام قياسية عالمية + رفض الأوقات المستحيلة
- [x] PLAY ONLINE (قائمة سيرفرات من الـ backend)
- [ ] ربط الحساب بإيميل / Google (لنقل الحساب لجهاز تاني)
- [ ] "انضم لصديق" مباشرة (presence عبر realtime socket)
- [ ] تخصيص الأفاتار (قبعات، إكسسوارات)

## المرحلة 4 — أكتر من لعبة (✅ النسخة الأولى)
- [x] نظام Experience + GameMode (السيرفر/الهوست هو الحَكَم) + Catalog
- [x] صفحة Discover بتبويبات (PLAY / AVATAR / FRIENDS / RECORDS / SETTINGS)
- [x] 4 ألعاب: Roobox Island، Lava Rising، Color Drop، Obby Rush
- [x] سيرفر مستقل لكل لعبة + PLAY ONLINE حسب اللعبة + لوحات أرقام لكل لعبة
- [ ] عدد اللاعبين الحالي بكل لعبة + تقييم/إعجاب
- [ ] أكتر من سيرفر للعبة الوحدة (instances) + matchmaking

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
