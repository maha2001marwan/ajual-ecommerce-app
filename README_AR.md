# Ajual — دليل التحديث والتشغيل

تمّت مطابقة التطبيق مع ملف التصميم (E-Commerce Mobile App UI Kit، 33 صفحة)، وربطه بـ Firebase على **الخطة المجانية (Spark)**. أيّ ميزة تحتاج خطة مدفوعة تعمل ببيانات ومنطق تجريبي (Demo) واضح داخل التطبيق.

> مهم: لم يكن بالإمكان تشغيل `flutter analyze` في بيئة العمل (لا يتوفر Flutter SDK). فُحص الكود آلياً من ناحية الأقواس والاستيرادات وأسماء المعاملات والأعضاء. شغّل `flutter pub get` ثم `flutter analyze` عندك أولاً، وأرسل لي أي خطأ يظهر.

---

## 1) ما يجب تفعيله في Firebase Console (كلّه مجاني)

| المكان | الإجراء |
|---|---|
| **Authentication → Sign-in method** | فعّل **Email/Password** و**Google**. فعّل **Apple** فقط إذا عندك حساب Apple Developer. |
| **Project settings → Your apps (Android)** | أضف بصمات **SHA-1 و SHA-256** (`cd android && ./gradlew signingReport`) ثم نزّل `google-services.json` الجديد. بدونها لا يعمل تسجيل Google. |
| **Firestore Database** | أنشئ قاعدة البيانات (Production mode)، ثم انشر القواعد: `firebase deploy --only firestore:rules` (يعمل على Spark). |
| **Authentication → Templates** | (اختياري) عدّل قالب رسالة **Password reset** واللغة. |
| **Cloud Messaging** | يعمل مجاناً على أندرويد. لـ iOS: ارفع مفتاح APNs (يحتاج حساب Apple Developer) وفعّل Push Notifications في Xcode. |
| **Authentication → Settings → Authorized domains** | أضف دومينك إذا ستشغّل نسخة الويب. |

**بيانات الكتالوج تُنشأ تلقائياً:** أول مستخدم يسجّل الدخول يكتب المنتجات والأقسام والكوبونات في Firestore (نسخة الكتالوج 7). بعدها تقفل القواعد الكتالوج فلا يستطيع أي مستخدم تعديله. إذا كان مشروعك يحتوي كتالوجاً أقدم، سيُستبدل تلقائياً عند أول تسجيل دخول **بشرط نشر القواعد الجديدة أولاً** (`firebase deploy --only firestore:rules`)، لأن القواعد القديمة ترفض التحديث فتبقى الصور والبيانات القديمة.

لا توجد فهارس مركّبة مطلوبة (`firestore.indexes.json` فارغ عمداً).

---

## 2) ما يعمل ببيانات تجريبية (Demo) لأنه يحتاج خطة مدفوعة

| الميزة | لماذا Demo | السلوك الحالي |
|---|---|---|
| رمز إعادة التعيين المكوّن من 4 أرقام بالبريد | يحتاج Cloud Functions + SMTP (Blaze) | يُرسل رابط Firebase الرسمي **الحقيقي** لإعادة التعيين، ويُعرض الرمز على الشاشة في شريط "Demo code" لتجربة الشاشات |
| الدفع بالبطاقة / PayPal | يحتاج بوابة دفع | الدفع عند الاستلام حقيقي. البطاقة وPayPal يحاكيان عملية دفع ناجحة دون أي خصم. تُحفظ البطاقة بآخر 4 أرقام فقط |
| تقدّم حالة الطلب (شُحن، وصل…) | لا يوجد Backend على Spark | الطلب يتقدّم تلقائياً خطوة كل 3 دقائق (`AppConfig.simulatedStepMinutes`) مع إشعار داخل التطبيق |
| صورة الحساب وصور/فيديو التقييمات | Cloud Storage يحتاج Blaze للمشاريع الجديدة | أفاتارات جاهزة، وعدد الصور يُحفظ دون رفع |
| Push عند تغيّر حالة الطلب من السيرفر | Cloud Functions | الإشعارات داخل التطبيق حقيقية. يمكنك إرسال Push يدوياً من Firebase Console مجاناً |
| أسعار صرف العملات | API مدفوع | أسعار ثابتة تقريبية (USD, EUR, GBP, ILS, JOD) |
| البحث بالصورة، الدردشة المباشرة | خدمات مدفوعة | زر يوضّح أنها Demo |

### عند الترقية إلى Blaze
غيّر في `lib/core/config/app_config.dart`:
```dart
static const bool useCloudFunctions = true;      // الطلبات وإعادة كلمة المرور عبر الدوال
static const bool simulateOrderProgress = false; // الحالة تتحدث من السيرفر
```
ثم انشر مجلد `functions/` الموجود لديك، وقيّد تحديث الطلبات في القواعد على المدير فقط.

---

## 3) خريطة الشاشات (صفحة التصميم ← الملف)

| صفحة التصميم | الملف | الحالة |
|---|---|---|
| 1، 5 Onboarding | `Screens/onboarding/onboarding_screen.dart` | معدّلة |
| 6 Sign In | `Screens/auth/login_screen.dart` | معدّلة |
| 7 Forgot Password | `Screens/auth/forgot_password_screen.dart` | معدّلة |
| 8 Verify Code | `Screens/auth/verify_code_screen.dart` | معدّلة |
| 9 Create New Password | `Screens/auth/new_password_screen.dart` | معدّلة |
| 10 Create An Account | `Screens/auth/signup_screen.dart` | معدّلة (حسب التصميم: الاسم، البريد، كلمة المرور) |
| 2، 11 Home | `Screens/home_page.dart` | أُعيد بناؤها |
| 12، 13 Search | `Screens/search/search_screen.dart` | **جديدة** |
| 3، 14 Categories | `Screens/categories/categories_screen.dart` | **جديدة** |
| 15 قائمة المنتجات | `Screens/products/product_list_screen.dart` | **جديدة** |
| 16 Filter | `Screens/products/filter_sheet.dart` | **جديدة** |
| 17 Product Details | `Screens/product_details.dart` | أُعيد بناؤها |
| 18 Wishlist | `Screens/favorite_page.dart` | أُعيد بناؤها |
| 19 Shopping Cart | `Screens/cart.dart` | أُعيد بناؤها |
| 20 Checkout | `Screens/checkout_screen.dart` | أُعيد بناؤها |
| 21 Delivery Address | `Screens/checkout/address_list_screen.dart` | **جديدة** |
| 22 Add Delivery Address | `Screens/checkout/add_address_screen.dart` | **جديدة** |
| 23 Credit Card | `Screens/checkout/card_sheet.dart` | **جديدة** |
| 24 Add New Card | `Screens/checkout/add_card_screen.dart` | **جديدة** |
| 25 Coupons | `Screens/checkout/coupons_screen.dart` | **جديدة** |
| 26 My Order | `Screens/orders_screen.dart` | أُعيد بناؤها |
| 27، 28 Search Order | `Screens/orders/order_search_screen.dart` | **جديدة** |
| 29، 30 Order Detail | `Screens/orders/order_detail_screen.dart` | **جديدة** |
| 31 Track Order | `Screens/orders/track_order_screen.dart` | **جديدة** |
| 4، 32 Account | `Screens/profile_screen.dart` | أُعيد بناؤها |
| 33 Edit Profile | `Screens/profile/edit_profile_screen.dart` | **جديدة** |
| — (مكمّلة للتدفق) | `order_success_screen`، `payment_methods_screen` (My Wallet)، `recently_viewed_screen`، `help_center_screen` (Help Center + Customer Service)، `my_reviews_screen`، `notifications_screen` | جديدة أو معدّلة |

شريط التنقل السفلي أصبح كما في التصميم: كبسولة سوداء عائمة بأربع أيقونات (الرئيسية، الأقسام، المفضلة، الحساب). السلة تفتح من أيقونة الحقيبة في الهيدر.

---

## 4) الحركات (3 على الأقل في كل شاشة)

عُدّة الحركة في `lib/core/animations/`:
- `motion.dart`: ظهور متتابع (Stagger)، وتصغير عند الضغط، واهتزاز عند الخطأ، ونقطة نابضة، وأرقام تعدّ تصاعدياً، ونص يتدحرج عند التغيّر.
- `effects.dart`: Shimmer للتحميل، وطيران المنتج إلى السلة على منحنى، ونبضة أيقونة السلة، وقلب المفضلة مع انفجار جزيئات، وعلامة صح تُرسم تدريجياً، وقصاصات احتفال.

أمثلة مميزة: طيران صورة المنتج إلى السلة، وقلب البطاقة ثلاثي الأبعاد عند كتابة CVV، وزر Get Started الذي تنزلق دائرته عبره، وعدّاد Flash Sale بأرقام متدحرجة، وفقاعة شريط التنقل المنزلقة مع اختفائه عند التمرير لأسفل، وشريط الشحن المجاني الذي يمتلئ ويحتفل، وتذاكر الكوبونات المرسومة، وخط تتبع الطلب الذي يمتلئ. كل الحركات تحترم إعداد تقليل الحركة في النظام.

---

## 5) تفاصيل تقنية أخرى
- **تحديث متفائل (Optimistic):** السلة والمفضلة وتحديد العناصر تتحدث فوراً وتتراجع تلقائياً عند الخطأ.
- **سلة بخيارات:** كل لون أو مقاس سطر مستقل، ويمكن تغييره من السلة. السلال القديمة (المحفوظة بمعرّف المنتج) ما زالت تُقرأ.
- **Checkout:** يُتحقق من العنوان والمخزون والكوبون والحد الأدنى للطلب. يُكتب الطلب والإشعار في عملية Batch واحدة، وتُحذف من السلة العناصر المطلوبة فقط.
- **القواعد (`firestore.rules`):** تتحقق من بنية الطلب وانتقالات الحالة المسموحة، ومن أن البطاقة لا تحوي رقماً كاملاً أو CVV، وأن التقييم واحد لكل مستخدم بين 1 و5.
- **إمكانية الوصول:** Semantics للأزرار، ومحدود تكبير الخط بين 0.9 و1.25، وTooltips، وزر الرجوع في أندرويد يعود للتبويب الرئيسي.
- أُزيلت حزمة `google_nav_bar` لأنها لم تعد مستخدمة. لا توجد حزم جديدة.

### حدود معروفة
- على Spark تُحسب أسعار الطلب في التطبيق (لا يوجد سيرفر يعيد التحقق منها). هذا مقبول للتجربة، أما للإنتاج فاستخدم Cloud Functions.
- واجهة اللغة العربية غير مترجمة بعد؛ خيار "العربية" موجود في الإعدادات ومعلَّم "قريباً".
- صور المنتجات: كل منتج له علامة تجارية (Meta Quest 3S، AirPods Max، MacBook Air، iPhone 14 Pro، Sony ZV-E10، Philips، Samsung، LG، Epson، Tissot…) يعرض صورة المنتج نفسه، جُلبت بالاسم عبر **Wikimedia Commons API** (مجاني وبدون مفتاح) ومضمّنة في `assets/images/products/` لأن Commons يحدّ من تحميل الصور مباشرة من التطبيقات. العطر وأحمر الشفاه والحقيبة من **DummyJSON products API**. المنتجات بلا علامة واضحة والأقسام من Unsplash وPexels. المصادر والتراخيص (معظمها يتطلب ذكر المصدر) في `assets/images/CREDITS.md`.
- إذا كان الكتالوج في Firestore أقدم من نسخة التطبيق (مثلاً لم تُنشر القواعد بعد)، يعرض التطبيق الكتالوج المضمّن فيه بدلاً من البيانات القديمة، فتظهر الأسماء والصور الصحيحة في كل الأحوال.
- عند تحديث الكتالوج، ارفع `catalogVersion` في `lib/core/config/app_config.dart` **و**الرقم في `catalogUnlocked()` داخل `firestore.rules` إلى القيمة نفسها، ثم انشر القواعد. (كان الرقمان مختلفين سابقاً — 5 في التطبيق و4 في القواعد — فرُفض تحديث الكتالوج وبقيت الصور القديمة.)
