import 'package:flutter/material.dart';
import '../config/app_colors.dart';

enum LegalType { privacy, terms }

class LegalScreen extends StatelessWidget {
  final LegalType type;
  const LegalScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isPrivacy = type == LegalType.privacy;
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      appBar: AppBar(
        title: Text(
          isPrivacy ? 'Privacy Policy' : 'Terms of Service',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: isPrivacy ? _privacySections() : _termsSections(),
        ),
      ),
    );
  }

  List<Widget> _privacySections() {
    return [
      _Header('Məxfilik Siyasəti / Политика конфиденциальности'),
      _Updated('Son yenilənmə / Последнее обновление: 25 May 2025'),
      _Body('''
Balanzo (biz, bizim) bu Məxfilik Siyasəti ilə siz tərəfindən təqdim edilən məlumatların necə toplandığını, istifadə edildiyini və qorunduğunu izah edir.

---

**AZ — Azərbaycan dili**

**1. Hansı məlumatlar toplanır?**
- Ad, e-poçt, telefon nömrəsi (qeydiyyat zamanı)
- Kassalar, məhsullar, qiymətlər (siz əlavə etdikdə)
- Cihaz məlumatları (analitika üçün)

**2. Məlumatlar necə istifadə olunur?**
- Xidmətin göstərilməsi üçün
- Büdcə idarəetmə xüsusiyyətlərinin işə salınması üçün
- Xidmət keyfiyyətinin yaxşılaşdırılması üçün

**3. Məlumatlar kiminlə paylaşılır?**
- Supabase (verilənlər bazası) — infrastruktur tərəfdaşı
- Anthropic (Claude AI) — AI məlumat emalı üçün
- Üçüncü şəxslərlə satılmır

**4. Silinmə hüququ**
"Hesabı sil" düyməsi vasitəsilə bütün məlumatlarınızı silə bilərsiniz.

---

**RU — Русский язык**

**1. Какие данные собираются?**
- Имя, e-mail, номер телефона (при регистрации)
- Данные о чеках и покупках (которые вы добавляете)
- Данные устройства (для аналитики)

**2. Как используются данные?**
- Для предоставления услуг приложения
- Для работы функций управления бюджетом
- Для улучшения качества сервиса

**3. С кем делятся данные?**
- Supabase (база данных) — инфраструктурный партнёр
- Anthropic (Claude AI) — обработка данных ИИ
- Не продаются третьим лицам

**4. Право на удаление**
Вы можете удалить все данные через кнопку "Удалить аккаунт" в настройках.

---

**Contact / Əlaqə:** support@balanzo.app
'''),
    ];
  }

  List<Widget> _termsSections() {
    return [
      _Header('İstifadə Şərtləri / Условия использования'),
      _Updated('Son yenilənmə / Последнее обновление: 25 May 2025'),
      _Body('''
**AZ — Azərbaycan dili**

Balanzo tətbiqindən istifadə etməklə siz aşağıdakı şərtləri qəbul etmiş olursunuz:

**1. Xidmətin istifadəsi**
- Tətbiq şəxsi maliyyə idarəetməsi üçün nəzərdə tutulub
- Hesabınızı başqasına vermək qadağandır
- Qanuna zidd məlumatlar əlavə etmək qadağandır

**2. Ödənişlər**
- Pulsuz plan hər zaman mövcuddur
- Aylıq abunə \$0.99 (AI Premium) və ya \$1.99 (Ailə Planı)
- Ödənişlər geri qaytarılmır, lakin istənilən vaxt ləğv etmək mümkündür

**3. Məsuliyyət**
- Balanzo maliyyə məsləhəti vermir
- AI cavabları informasiya məqsədli olub, maliyyə qərarı üçün əsas sayılmaz
- Tətbiqdəki məlumatların düzgünlüyünə görə istifadəçi məsuldur

**4. Xidmətin dayandırılması**
Şərtlərə uyğunsuz istifadə halında hesabınız bloklanıla bilər.

---

**RU — Русский язык**

Используя приложение Balanzo, вы принимаете следующие условия:

**1. Использование сервиса**
- Приложение предназначено для личного управления финансами
- Запрещена передача аккаунта третьим лицам
- Запрещено добавление незаконных данных

**2. Оплата**
- Бесплатный план доступен всегда
- Ежемесячная подписка: \$0.99 (AI Premium) или \$1.99 (Семейный план)
- Платежи не возвращаются, но подписку можно отменить в любое время

**3. Ответственность**
- Balanzo не предоставляет финансовые консультации
- Ответы ИИ носят информационный характер и не являются финансовыми советами
- Пользователь несёт ответственность за точность данных в приложении

**4. Блокировка аккаунта**
Аккаунт может быть заблокирован при нарушении условий использования.

---

**Contact / Əlaqə:** support@balanzo.app
'''),
    ];
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );
}

class _Updated extends StatelessWidget {
  final String text;
  const _Updated(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      );
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 14, height: 1.6));
}
