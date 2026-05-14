# FootballBook

تطبيق Flutter لحجز ملاعب كرة القدم: لاعب، مالك ملعب، ولوحة أدمن. يستخدم **Riverpod**، **go_router**، **Dio** للـ REST، و**Firebase** (Core، Messaging، Firestore) على Android و iOS والويب.

## المتطلبات

- Flutter SDK ضمن النطاق المذكور في `pubspec.yaml` (حاليًا Dart `>=3.10.1`)

## التشغيل

```bash
flutter pub get
flutter run
```

## عنوان الـ API (بيئات مختلفة)

بدون تعريفات، يُستخدم العنوان الافتراضي الموجود في `lib/core/network/base_url.dart`.

لتجاوزه عند البناء أو التشغيل:

```bash
flutter run --dart-define=API_ORIGIN=https://your-host.com
```

أو عنوان الـ base كاملًا (يفضّل أن ينتهي بـ `/api/v1/`):

```bash
flutter run --dart-define=API_BASE_URL=https://your-host.com/api/v1/
```

## أيقونات التطبيق

```bash
dart run flutter_launcher_icons
```

## الترجمة (l10n)

ملفات ARB في `lib/l10n/`. بعد التعديل:

```bash
flutter gen-l10n
```

(غالبًا يُنفَّذ تلقائيًا مع `flutter pub get` عند `generate: true`.)

## Firebase

- شغّل `flutterfire configure` لتحديث `lib/firebase_options.dart` لجميع المنصات المطلوبة.
- على **Windows / macOS / Linux** التطبيق يتخطّى تهيئة Firebase إن لم تكن الخيارات مضبوطة (لتفادي الـ crash)، مع العلم أن ميزات تعتمد على Firestore/FCM لن تعمل على تلك المنصات حتى تُكوَّن.

### ملفات حساسة

لا ترفع `google-services.json` أو `GoogleService-Info.plist` إلى مستودع عام؛ أضفها محليًا من [Firebase Console](https://console.firebase.google.com/). المستودع يتضمّن قواعد `.gitignore` لهذه الأسماء للنسخ الجديدة.

## الموقع الجغرافي

البحث عن الملاعب القريبة يستخدم **geolocator** عند السماح بالأذونات؛ عند الرفض أو عدم توفر الموقع يُستخدم افتراضيًا مركز تقريبي للقاهرة (انظر `lib/core/location/user_location_resolver.dart`).

## الاختبارات و التحليل

```bash
flutter analyze
flutter test
```
