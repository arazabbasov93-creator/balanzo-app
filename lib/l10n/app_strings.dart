class AppStrings {
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      // Nav
      'home': 'Home',
      'receipts': 'Receipts',
      'restock': 'Restock',
      'ai_chat': 'Ask Balanzo',
      'profile': 'Profile',
      'nav_home': 'Home',
      'nav_receipts': 'Receipts',
      'nav_restock': 'Restock',
      'nav_ai': 'Balanzo',
      'nav_profile': 'Profile',
      // Common actions
      'cancel': 'Cancel',
      'retry': 'Retry',
      'refresh': 'Refresh',
      'save': 'Save',
      'leave': 'Leave',
      'claim': 'Claim',
      'add_item': 'Add Item',
      'see_all': 'See all',
      'delete': 'Delete',
      'edit': 'Edit',
      // Receipt capture
      'scan_receipt': 'Scan Receipt',
      'manual_entry': 'Manual Entry',
      'add_receipt': 'Add Receipt',
      'process_receipt': 'Process Receipt',
      'scan_photo_instead': 'Scan Photo Receipt Instead',
      'enter_fiscal_manually': 'Enter Fiscal ID Manually',
      'enter_fiscal_id': 'Enter Fiscal ID',
      'enter_fiscal_hint': 'Enter the document ID from your e-kassa receipt.',
      'fetch_receipt': 'Fetch Receipt',
      'save_receipt': 'Save Receipt',
      'saving': 'Saving...',
      'scan_qr_code': 'Scan QR Code',
      'scan_ekassa_qr': 'Scan e-kassa QR',
      'scan_qr_hint': 'Point at the QR code on your receipt',
      'take_photo': 'Take Photo',
      'upload_from_gallery': 'Upload from Gallery',
      'fetching_receipt': 'Fetching receipt {id}…',
      'processing_receipt': 'Processing receipt...',
      // Home / Dashboard
      'monthly_spend': 'Monthly Spend',
      'budget_alerts': 'Budget Alerts',
      'recent_receipts': 'Recent Receipts',
      'vs_last_month': 'vs last month',
      'error_loading_data': 'Error loading data',
      'no_receipts_yet': 'No receipts yet',
      'scan_to_start': 'Scan a receipt to get started',
      'scan_first_receipt': 'Scan your first receipt to start tracking',
      'spent_in': 'Spent in',
      'tab_personal': 'Personal',
      'tab_family': 'Family',
      'dash_avg_receipt': 'Avg receipt',
      'dash_stores': 'Stores',
      'dash_items': 'Items',
      'dash_this_week': 'This week',
      'dash_last_week': 'Last week',
      'dash_this_month': 'This month',
      'dash_last_month': 'Last month',
      'dash_last_year_month': 'Same month last year',
      'dash_vs_last_month': 'vs last month',
      'dash_vs_last_year': 'vs last year (this month)',
      'ai_upgrade': 'Upgrade',
      'dash_top_category': 'Top category',
      'dash_top_stores': 'Top stores',
      'dash_most_bought': 'Most bought',
      'dash_most_often': 'Buy most often',
      'dash_top_spend_item': 'Biggest spend',
      'dash_period_fallback': 'No receipts this month yet — showing',
      'dash_no_categories': 'Receipts saved, but categories are missing for this period.',
      'dash_inflation': 'Price change',
      'dash_most_by_qty': 'Most by quantity',
      'dash_most_by_value': 'Most by spend',
      'dash_qty_unit': 'qty',
      'dash_category_spend': 'Category spend',
      'dash_no_category_items': 'No line items found for this category.',
      'dash_tap_for_details': 'Tap a row for details',
      'budget_section': 'Budget',
      'budget_limits': 'Category limits',
      'income_total': 'Income',
      'spend_total': 'Spent',
      'remaining_balance': 'Left to spend',
      'family_income_total': 'Family income',
      'family_spend_total': 'Family spent',
      'income_editor_title': 'Your income this month',
      'income_label': 'Source (salary, freelance…)',
      'income_amount': 'Amount (AZN)',
      'income_preset_salary': 'Salary',
      'income_preset_rent': 'Rent',
      'income_preset_freelance': 'Freelance',
      'income_add_source': 'Add income source',
      'income_recurring': 'Recurring every month',
      'income_one_time': 'One-time this month',
      'income_type_label': 'Income type',
      'income_edit_source': 'Edit income source',
      'income_delete': 'Delete',
      'duplicate_receipt_title': 'Receipt already saved',
      'soft_duplicate_title': 'Looks familiar',
      'soft_duplicate_body': 'Looks like a receipt from {store} was already saved. Save anyway?',
      'save_anyway': 'Save anyway',
      'view_existing': 'View existing',
      'view_receipt': 'View receipt',
      'restock_ignore': 'Ignore',
      'restock_bought': 'Bought',
      'restock_clear': 'Clear',
      'restock_avg_qty': 'Usual qty',
      'restock_latest_price': 'Last price',
      'restock_est_budget': 'Est. list total',
      'restock_items_due': 'items on your list',
      'restock_tap_hint': 'Mark bought or ignore',
      'restock_days_overdue': 'days overdue',
      'restock_due_today': 'Due today',
      'restock_due_in': 'Due in',
      'restock_days': 'days',
      'restock_every': 'Every',
      'restock_ignored': 'Ignored',
      'share_shopping_list': 'Share list',
      'restock_share_header': 'Shopping List (Balanzo):',
      'restock_share_est_total': 'Est. total:',
      // Receipts
      'search_receipts': 'Search by store name…',
      'failed_to_load': 'Failed to load receipts',
      // Restock
      'due_for_restock': 'Due for Restock',
      'marked_as_bought': 'Marked as Bought',
      'no_restock_yet': 'No restock predictions yet',
      'restock_scan_hint': 'Scan at least 2 receipts with the same items to see restock predictions.',
      // AI Chat
      'ai_assistant': 'Balanzo AI',
      'ai_disclaimer': 'Balanzo AI can make mistakes. Nothing here is financial advice. Please double check responses.',
      'ask_spending': 'Ask about your spending...',
      'thinking': 'Thinking...',
      // Profile
      'profile_settings': 'Profile & Settings',
      'preferences': 'Preferences',
      'subscription': 'Subscription',
      'account': 'Account',
      'language': 'Language',
      'notifications': 'Notifications',
      'notif_empty': 'No notifications yet',
      'notif_clear': 'Clear',
      'notif_mark_all_read': 'Mark all as read',
      'notif_mark_unread': 'Mark unread',
      'notif_detail_title': 'Notification',
      'notif_restock_title': 'Restock Reminder',
      'notif_restock_body': 'You usually buy "{itemName}" around now.',
      'support': 'Support',
      'support_intro': 'Need help with Balanzo? Use the report button on any receipt to send us details, including your receipt number.',
      'support_report_hint': 'Reporting a receipt issue',
      'support_report_steps': 'Open the receipt, tap Report, describe the problem, and submit. We store your report with the receipt sequence number for faster support.',
      'report_receipt': 'Report',
      'report_receipt_title': 'Report receipt issue',
      'report_receipt_hint': 'Describe the problem (wrong items, totals, etc.)',
      'report_receipt_submit': 'Submit report',
      'report_receipt_success': 'Report submitted. Thank you!',
      'report_already_reported': 'This receipt has already been reported',
      'report_existing_status': 'Status',
      'report_something_else': 'Report something else',
      'report_new_title': 'Add to report',
      'receipt_number': 'Receipt #',
      'sign_out': 'Sign Out',
      'delete_account': 'Delete Account',
      'upgrade': 'Get Premium',
      'upgrade_to_premium': 'Upgrade to Premium',
      'upgrade_screen_title': 'Upgrade Balanzo',
      'upgrade_hero_title': 'Unlock the Full Balanzo',
      'upgrade_hero_subtitle': 'AI-powered insights, family sharing, and more',
      'upgrade_choose_plan': 'Choose your plan',
      'upgrade_free_forever': 'Free — forever',
      'upgrade_most_popular': 'Most Popular',
      'upgrade_monthly': 'Monthly',
      'upgrade_annual': 'Annual',
      'upgrade_save_16': 'Save 16%',
      'upgrade_now': 'Upgrade Now',
      'upgrade_cancel_note': 'Cancel anytime. Payments processed securely.',
      'upgrade_success': 'Subscription updated! Enjoy Balanzo Premium.',
      'get_premium': 'Get Premium',
      'free_plan': 'Free Plan',
      'ai_premium': 'AI Premium',
      'family_plan': 'Family Plan',
      'share_my_stats': 'Share My Stats',
      // Categories & settings
      'categories': 'Categories',
      'new_category': 'New Category',
      'category_name_label': 'Category name',
      'category_default': 'Default',
      'add_category': 'Add',
      'error_generic': 'Error',
      'ai_assistant_unavailable': 'AI assistant is not available right now.',
      'ai_premium_messages_left': '{count} messages left this month',
      'ai_premium_limit_reached': 'Monthly limit reached ({limit} messages). Resets on {resetDate}.',
      'ai_premium_limit_title': 'Monthly AI limit reached',
      'ai_free_limit_title': 'Free tier includes 1 message per week',
      'ai_free_limit_body': 'Upgrade to Premium for more messages, 90 days of spending history, and full AI insights.',
      'ai_maybe_later': 'Maybe later',
      'ai_response_error': 'Sorry, I couldn\'t get a response right now.',
      'ai_network_error': 'Network error. Please try again.',
      'sign_in_title': 'Sign in or create account',
      'sign_in_subtitle': 'Choose your preferred sign-in method',
      'sign_in_terms': 'By continuing, you agree to our Terms of Service and Privacy Policy',
      'app_tagline': 'Family budget made simple',
      'continue_with_google': 'Continue with Google',
      'continue_with_apple': 'Continue with Apple',
      'sign_in_cancelled': 'Sign-in cancelled.',
      'sign_in_rejected': 'Sign-in rejected by server. Check provider settings in Supabase Auth.',
      'sign_in_google_config': 'Google Sign-In not configured for this app build (SHA-1 / Firebase).',
      'sign_in_network': 'Cannot reach server. Check Wi‑Fi/mobile data and try again.',
      'fiscal_document_id': 'Fiscal Document ID',
      'fiscal_id_hint': 'E7av3BYTEgRV or full QR URL',
      'fiscal_id_help': 'Find this ID on your paper receipt or in your e-mail confirmation.',
      'fiscal_id_required': 'Please enter a fiscal document ID',
      'fiscal_ekassa_note': 'Receipts fetched by Fiscal ID are verified directly against the Azerbaijan e-kassa government database.',
      'photo_hint_top': 'Start at the top of the receipt',
      'photo_hint_middle': 'Overlap slightly — capture the middle',
      'photo_hint_bottom': 'Capture the bottom of the receipt',
      'photo_hint_more': 'Add more sections or tap Process.',
      'analytics': 'Analytics',
      'vat_tracker': 'VAT Tracker',
      'privacy_policy': 'Privacy Policy',
      'terms': 'Terms of Service',
      'about': 'About',
      'settings': 'Settings',
      'last_7_days': 'Seeing last 7 days · Get Premium',
      'last_30_days': 'Seeing last 30 days · Get Premium',
      // Family
      'family': 'Family',
      'no_family_yet': 'No Family Yet',
      'no_family_desc': 'Create a family to share expenses and budgets with others.',
      'create_family': 'Create Family',
      'leave_family': 'Leave Family',
      'add_member': 'Add Member',
      'members': 'Members',
      'combined_spend': 'Combined spend this month',
      'family_available_budget': 'Available budget',
      'family_spent_label': 'Spent',
      'family_budget_not_set': 'Not set',
      'family_admin_badge_hint': 'Family admin',
      'share_personal_budget_with_family': 'Share my personal budget with family',
      'share_personal_budget_hint': 'When enabled, family members can see your personal budget on the Home family tab.',
      'family_member_spend': 'Spent',
      'family_member_limit': 'Limit',
      'invite_whatsapp': 'Invite via WhatsApp',
      'whatsapp_invite_message':
          'Join {familyName} on Balanzo!\n\nTap to join directly:\n{inviteLink}\n\nOr install the app first:\nhttps://balanzo.app',
      'family_invite_invalid': 'This family invite link is invalid.',
      'family_invite_expired': 'This family invite has expired. Ask for a new invite.',
      'family_invite_error_generic': 'Could not join the family. Please try again.',
      'family_invite_joined_title': 'Welcome to the family',
      'family_invite_success_generic': 'You have joined the family.',
      'family_name_hint': 'Family name (e.g. Əliyev family)',
      'phone_number_label': 'Phone number',
      'leave_family_confirm': 'Are you sure you want to leave this family?',
      'family_role_admin': 'Admin',
      'family_role_co_admin': 'Co-admin',
      'family_role_member': 'Member',
      'family_relationship_label': 'Relationship',
      'family_relationship_unset': 'Not set',
      'family_relationship_father': 'Father',
      'family_relationship_mother': 'Mother',
      'family_relationship_son': 'Son',
      'family_relationship_daughter': 'Daughter',
      'family_relationship_spouse': 'Spouse',
      'family_relationship_sibling': 'Sibling',
      'family_relationship_other': 'Other',
      'spend_limit': 'Spend limit',
      'set_spend_limit': 'Set spend limit',
      'spend_limit_confirm': 'Confirm limit',
      'spend_limit_pending': 'Pending limit: {amount} AZN',
      'spend_limit_proposed_hint': 'An admin proposed a new spend limit',
      'spend_limit_locked_reason':
          'Spend limit was set this month and cannot be changed until next month.',
      'support_no_reports': 'No reports yet. Use Report on a receipt to contact us.',
      'support_detail_title': 'Report details',
      'support_status_open': 'Open',
      'support_status_resolved': 'Resolved',
      // Manual entry
      'store_name': 'Store Name',
      'date_label': 'Date',
      'payment_method': 'Payment Method',
      'items_label': 'Items',
      'total_label': 'Total',
      // Manual entry extra
      'cash': 'Cash',
      'card': 'Card',
      // VAT Tracker
      'no_vat_data': 'No VAT data yet',
      'vat_scan_hint': 'Scan receipts with VAT to start tracking your claimable VAT.',
      'total_vat_paid': 'Total VAT Paid',
      'unclaimed': 'Unclaimed',
      'unclaimed_vat': 'Unclaimed VAT',
      'claimed': 'Claimed',
      // Category names
      'cat_meat': 'Meat',
      'cat_dairy': 'Dairy',
      'cat_vegetables': 'Vegetables',
      'cat_household': 'Household',
      'cat_grocery': 'Grocery',
      'cat_restaurant': 'Restaurant',
      'cat_tobacco': 'Tobacco',
      'cat_transport': 'Transport',
      'cat_health': 'Health',
      'cat_clothing': 'Clothing',
      'cat_utilities': 'Utilities',
      'cat_education': 'Education',
      'cat_other': 'Other',
      'no_receipts_in_period': 'No receipts in this period',
      'income_sources': 'Income sources',
      'filter_by_category': 'Filter by category',
      'select_month': 'Select month',
      'select_year': 'Select year',
      'confirm': 'Confirm',
      'edit_category': 'Edit category',
      'pick_icon': 'Pick icon',
      'pick_color': 'Pick color',
      'select_category': 'Select category',
      'family_members': 'Family members',
      'currency': 'Currency',
      'category': 'Category',
      'most_bought_need_more': 'Add more receipts to see your most frequently bought items',
    },
    'az': {
      // Nav
      'home': 'Ana Səhifə',
      'receipts': 'Qəbzlər',
      'restock': 'Yenidən Stok',
      'ai_chat': 'Balanzo-ya soruş',
      'profile': 'Profil',
      'nav_home': 'Əsas',
      'nav_receipts': 'Qəbzlər',
      'nav_restock': 'Stok',
      'nav_ai': 'Balanzo',
      'nav_profile': 'Profil',
      // Common actions
      'cancel': 'Ləğv et',
      'retry': 'Yenidən cəhd et',
      'refresh': 'Yenilə',
      'save': 'Saxla',
      'leave': 'Tərk et',
      'claim': 'Tələb et',
      'add_item': 'Məhsul əlavə et',
      'see_all': 'Hamısını gör',
      'delete': 'Sil',
      'edit': 'Düzəlt',
      // Receipt capture
      'scan_receipt': 'Qəbz Skan et',
      'manual_entry': 'Əl ilə daxil et',
      'add_receipt': 'Qəbz Əlavə Et',
      'process_receipt': 'Qəbzi emal et',
      'scan_photo_instead': 'Əvəzinə Foto Qəbz Skan et',
      'enter_fiscal_manually': 'Fiskal ID-ni əl ilə daxil edin',
      'enter_fiscal_id': 'Fiskal ID daxil edin',
      'enter_fiscal_hint': 'e-kassa qəbzinizdəki sənəd ID-ni daxil edin.',
      'fetch_receipt': 'Qəbzi əldə et',
      'save_receipt': 'Qəbzi saxla',
      'saving': 'Saxlanır...',
      'scan_qr_code': 'QR Kodu Skan et',
      'scan_ekassa_qr': 'e-kassa QR skan et',
      'scan_qr_hint': 'Qəbzinizdəki QR koduna yönəldin',
      'take_photo': 'Foto çək',
      'upload_from_gallery': 'Qalereyadan yüklə',
      'fetching_receipt': 'Qəbz əldə edilir {id}…',
      'processing_receipt': 'Qəbz emal edilir...',
      // Home / Dashboard
      'monthly_spend': 'Aylıq Xərc',
      'budget_alerts': 'Büdcə Xəbərdarlıqları',
      'recent_receipts': 'Son Qəbzlər',
      'vs_last_month': 'ötən aya nisbətən',
      'error_loading_data': 'Məlumat yüklənmədi',
      'no_receipts_yet': 'Hələlik qəbz yoxdur',
      'scan_to_start': 'Başlamaq üçün qəbz skan edin',
      'scan_first_receipt': 'İzləməyə başlamaq üçün ilk qəbzinizi skan edin',
      'spent_in': 'xərcləndi',
      'tab_personal': 'Şəxsi',
      'tab_family': 'Ailə',
      'dash_avg_receipt': 'Orta qəbz',
      'dash_stores': 'Mağazalar',
      'dash_items': 'Məhsul',
      'dash_this_week': 'Bu həftə',
      'dash_last_week': 'Keçən həftə',
      'dash_this_month': 'Bu ay',
      'dash_last_month': 'Keçən ay',
      'dash_last_year_month': 'Keçən il eyni ay',
      'dash_vs_last_month': 'keçən aya nisbətən',
      'dash_vs_last_year': 'keçən ilin eyni ayına nisbətən',
      'ai_upgrade': 'Yüksəlt',
      'dash_top_category': 'Əsas kateqoriya',
      'dash_top_stores': 'Top mağazalar',
      'dash_most_bought': 'Ən çox alınan',
      'dash_most_often': 'Tez-tez alınır',
      'dash_top_spend_item': 'Ən böyük xərc',
      'dash_period_fallback': 'Bu ay hələ qəbz yoxdur — göstərilir',
      'dash_no_categories': 'Qəbzlər var, amma bu dövr üçün kateqoriya məlumatı yoxdur.',
      'dash_inflation': 'Qiymət dəyişimi',
      'dash_most_by_qty': 'Ən çox miqdar',
      'dash_most_by_value': 'Ən böyük xərc',
      'dash_qty_unit': 'ədəd',
      'dash_category_spend': 'Kateqoriya xərci',
      'dash_no_category_items': 'Bu kateqoriya üçün məhsul tapılmadı.',
      'dash_tap_for_details': 'Detallar üçün toxunun',
      'budget_section': 'Büdcə',
      'budget_limits': 'Kateqoriya limitləri',
      'income_total': 'Gəlir',
      'spend_total': 'Xərc',
      'remaining_balance': 'Qalan',
      'family_income_total': 'Ailə gəliri',
      'family_spend_total': 'Ailə xərci',
      'income_editor_title': 'Bu ay gəliriniz',
      'income_label': 'Mənbə (maaş, freelance…)',
      'income_amount': 'Məbləğ (AZN)',
      'income_preset_salary': 'Maaş',
      'income_preset_rent': 'Kirayə',
      'income_preset_freelance': 'Freelance',
      'income_add_source': 'Gəlir mənbəyi əlavə et',
      'income_recurring': 'Hər ay təkrarlanan',
      'income_one_time': 'Yalnız bu ay',
      'income_type_label': 'Gəlir növü',
      'income_edit_source': 'Gəlir mənbəyini redaktə et',
      'income_delete': 'Sil',
      'duplicate_receipt_title': 'Qəbz artıq saxlanılıb',
      'soft_duplicate_title': 'Tanış görünür',
      'soft_duplicate_body': '{store} mağazasından oxşar qəbz artıq saxlanılıb. Yenə saxlayaq?',
      'save_anyway': 'Yenə saxla',
      'view_existing': 'Mövcudu gör',
      'view_receipt': 'Qəbzi aç',
      'restock_ignore': 'Yox say',
      'restock_bought': 'Alındı',
      'restock_clear': 'Təmizlə',
      'restock_avg_qty': 'Adi miqdar',
      'restock_latest_price': 'Son qiymət',
      'restock_est_budget': 'Təxmini siyahı',
      'restock_items_due': 'məhsul siyahıda',
      'restock_tap_hint': 'Alındı və ya yox say',
      'restock_days_overdue': 'gün gecikib',
      'restock_due_today': 'Bu gün',
      'restock_due_in': 'Son',
      'restock_days': 'gün',
      'restock_every': 'Hər',
      'restock_ignored': 'Yox sayılıb',
      'share_shopping_list': 'Siyahını paylaş',
      'restock_share_header': 'Alış-veriş siyahısı (Balanzo):',
      'restock_share_est_total': 'Təxmini cəm:',
      // Receipts
      'search_receipts': 'Mağaza adına görə axtar…',
      'failed_to_load': 'Qəbzlər yüklənmədi',
      // Restock
      'due_for_restock': 'Stok Vaxtı Gəlib',
      'marked_as_bought': 'Alındı Kimi Qeyd Edilib',
      'no_restock_yet': 'Hələlik stok proqnozu yoxdur',
      'restock_scan_hint': 'Proqnoz üçün eyni məhsullardan ən az 2 qəbz skan edin.',
      // AI Chat
      'ai_assistant': 'Balanzo AI',
      'ai_disclaimer': 'Balanzo AI səhvlər edə bilər. Heç bir məlumat maliyyə məsləhəti deyil. Cavabları təkrar yoxlayın.',
      'ask_spending': 'Xərclər haqqında soruşun...',
      'thinking': 'Düşünür...',
      // Profile
      'profile_settings': 'Profil və Parametrlər',
      'preferences': 'Seçimlər',
      'subscription': 'Abunə',
      'account': 'Hesab',
      'language': 'Dil',
      'notifications': 'Bildirişlər',
      'notif_empty': 'Hələ bildiriş yoxdur',
      'notif_clear': 'Təmizlə',
      'notif_mark_all_read': 'Hamısını oxunmuş et',
      'notif_mark_unread': 'Oxunmamış et',
      'notif_detail_title': 'Bildiriş',
      'notif_restock_title': 'Stok xatırlatması',
      'notif_restock_body': 'Adətən bu vaxtlar "{itemName}" alırsınız.',
      'support': 'Dəstək',
      'support_intro': 'Balanzo ilə bağlı kömək lazımdır? Qəbzdəki Hesabat düyməsindən istifadə edin — qəbz nömrəsi daxil olmaqla.',
      'support_report_hint': 'Qəbz problemi barədə müraciət',
      'support_report_steps': 'Qəbzi açın, Hesabat düyməsinə toxunun, problemi təsvir edin və göndərin.',
      'report_receipt': 'Hesabat',
      'report_receipt_title': 'Qəbz problemi',
      'report_receipt_hint': 'Problemi təsvir edin (səhv məhsul, məbləğ və s.)',
      'report_receipt_submit': 'Göndər',
      'report_receipt_success': 'Müraciət göndərildi. Təşəkkürlər!',
      'report_already_reported': 'Bu qəbz artıq müraciət edilib',
      'report_existing_status': 'Status',
      'report_something_else': 'Başqa bir şey bildir',
      'report_new_title': 'Müraciətə əlavə et',
      'receipt_number': 'Qəbz №',
      'sign_out': 'Çıxış',
      'delete_account': 'Hesabı sil',
      'upgrade': 'Premium al',
      'upgrade_to_premium': 'Premiuma Keçin',
      'upgrade_screen_title': 'Balanzo Premium',
      'upgrade_hero_title': 'Balanzonun tam imkanları',
      'upgrade_hero_subtitle': 'AI analitika, ailə paylaşımı və daha çox',
      'upgrade_choose_plan': 'Plan seçin',
      'upgrade_free_forever': 'Pulsuz — həmişəlik',
      'upgrade_most_popular': 'Ən populyar',
      'upgrade_monthly': 'Aylıq',
      'upgrade_annual': 'İllik',
      'upgrade_save_16': '16% endirim',
      'upgrade_now': 'İndi yüksəlt',
      'upgrade_cancel_note': 'İstənilən vaxt ləğv edin. Ödənişlər təhlükəsizdir.',
      'upgrade_success': 'Abunə yeniləndi! Balanzo Premium-dan həzz alın.',
      'get_premium': 'Premium al',
      'free_plan': 'Pulsuz Plan',
      'ai_premium': 'AI Premium',
      'family_plan': 'Ailə Planı',
      'share_my_stats': 'Statistikamı Paylaş',
      // Categories & settings
      'categories': 'Kateqoriyalar',
      'new_category': 'Yeni Kateqoriya',
      'category_name_label': 'Kateqoriya adı',
      'category_default': 'Standart',
      'add_category': 'Əlavə et',
      'error_generic': 'Xəta',
      'ai_assistant_unavailable': 'AI assistant hazırda əlçatan deyil.',
      'ai_premium_messages_left': 'Bu ay {count} mesaj qaldı',
      'ai_premium_limit_reached': 'Aylıq limit dolub ({limit} mesaj). {resetDate} tarixində yenilənir.',
      'ai_premium_limit_title': 'Aylıq AI limiti dolub',
      'ai_free_limit_title': 'Pulsuz planda həftədə 1 mesaj',
      'ai_free_limit_body': 'Daha çox mesaj, 90 günlük xərc tarixçəsi və tam AI analitikası üçün Premium-a keçin.',
      'ai_maybe_later': 'Sonra',
      'ai_response_error': 'Bağışlayın, hazırda cavab ala bilmədim.',
      'ai_network_error': 'Şəbəkə xətası. Yenidən cəhd edin.',
      'sign_in_title': 'Daxil olun və ya hesab yaradın',
      'sign_in_subtitle': 'Üstünlük verdiyiniz giriş üsulunu seçin',
      'sign_in_terms': 'Davam etməklə İstifadə Şərtləri və Məxfilik Siyasəti ilə razılaşırsınız',
      'app_tagline': 'Ailə büdcəsi sadədir',
      'continue_with_google': 'Google ilə davam et',
      'continue_with_apple': 'Apple ilə davam et',
      'sign_in_cancelled': 'Giriş ləğv edildi.',
      'sign_in_rejected': 'Server girişi rədd etdi. Supabase Auth provayder parametrlərini yoxlayın.',
      'sign_in_google_config': 'Google Sign-In bu build üçün konfiqurasiya edilməyib (SHA-1 / Firebase).',
      'sign_in_network': 'Serverə çatmaq mümkün deyil. Wi‑Fi/mobil interneti yoxlayın.',
      'fiscal_document_id': 'Fiskal Sənəd ID',
      'fiscal_id_hint': 'E7av3BYTEgRV və ya tam QR URL',
      'fiscal_id_help': 'Bu ID-ni kağız qəbzdə və ya e-poçt təsdiqində tapın.',
      'fiscal_id_required': 'Zəhmət olmasa fiskal sənəd ID daxil edin',
      'fiscal_ekassa_note': 'Fiskal ID ilə alınan qəbzlər birbaşa Azərbaycan e-kassa dövlət bazası ilə yoxlanılır.',
      'photo_hint_top': 'Qəbzin yuxarısından başlayın',
      'photo_hint_middle': 'Azca üst-üstə düşsün — orta hissəni çəkin',
      'photo_hint_bottom': 'Qəbzin alt hissəsini çəkin',
      'photo_hint_more': 'Daha çox bölmə əlavə edin və ya Emal et düyməsinə basın.',
      'analytics': 'Analitika',
      'vat_tracker': 'ƏDV İzləyici',
      'privacy_policy': 'Məxfilik Siyasəti',
      'terms': 'İstifadə Şərtləri',
      'about': 'Haqqında',
      'settings': 'Parametrlər',
      'last_7_days': 'Son 7 gün görünür · Premium al',
      'last_30_days': 'Son 30 gün görünür · Premium al',
      // Family
      'family': 'Ailə',
      'no_family_yet': 'Hələlik ailə yoxdur',
      'no_family_desc': 'Xərcləri başqaları ilə bölüşmək üçün ailə yaradın.',
      'create_family': 'Ailə yarat',
      'leave_family': 'Ailəni tərk et',
      'add_member': 'Üzv əlavə et',
      'members': 'Üzvlər',
      'combined_spend': 'Bu ay birgə xərc',
      'family_available_budget': 'Mövcud büdcə',
      'family_spent_label': 'Xərclənib',
      'family_budget_not_set': 'Təyin edilməyib',
      'family_admin_badge_hint': 'Ailə admini',
      'share_personal_budget_with_family': 'Şəxsi büdcəmi ailə ilə paylaş',
      'share_personal_budget_hint': 'Aktiv olanda ailə üzvləri Ana səhifədə sizin şəxsi büdcənizi görə bilər.',
      'family_member_spend': 'Xərclənib',
      'family_member_limit': 'Limit',
      'invite_whatsapp': 'WhatsApp ilə dəvət et',
      'whatsapp_invite_message':
          'Balanzoda {familyName} ailəsinə qoşulun!\n\nBirbaşa qoşulmaq üçün toxunun:\n{inviteLink}\n\nVə ya əvvəlcə tətbiqi yükləyin:\nhttps://balanzo.app',
      'family_invite_invalid': 'Bu ailə dəvət linki etibarsızdır.',
      'family_invite_expired': 'Bu dəvətin müddəti bitib. Yeni dəvət istəyin.',
      'family_invite_error_generic': 'Ailəyə qoşulmaq mümkün olmadı. Yenidən cəhd edin.',
      'family_invite_joined_title': 'Ailəyə xoş gəlmisiniz',
      'family_invite_success_generic': 'Ailəyə qoşuldunuz.',
      'family_name_hint': 'Ailə adı (məs. Əliyev ailəsi)',
      'phone_number_label': 'Telefon nömrəsi',
      'leave_family_confirm': 'Bu ailəni tərk etmək istədiyinizə əminsiniz?',
      'family_role_admin': 'Admin',
      'family_role_co_admin': 'Köməkçi admin',
      'family_role_member': 'Üzv',
      'family_relationship_label': 'Qohumluq',
      'family_relationship_unset': 'Təyin edilməyib',
      'family_relationship_father': 'Ata',
      'family_relationship_mother': 'Ana',
      'family_relationship_son': 'Oğul',
      'family_relationship_daughter': 'Qız',
      'family_relationship_spouse': 'Həyat yoldaşı',
      'family_relationship_sibling': 'Qardaş/bacı',
      'family_relationship_other': 'Digər',
      'spend_limit': 'Xərc limiti',
      'set_spend_limit': 'Xərc limiti təyin et',
      'spend_limit_confirm': 'Limiti təsdiqlə',
      'spend_limit_pending': 'Gözləyən limit: {amount} AZN',
      'spend_limit_proposed_hint': 'Admin yeni xərc limiti təklif edib',
      'spend_limit_locked_reason':
          'Xərc limiti bu ay təyin edilib və növbəti aya qədər dəyişdirilə bilməz.',
      'support_no_reports': 'Hələ müraciət yoxdur. Bizə yazmaq üçün qəbzdə Hesabat düyməsindən istifadə edin.',
      'support_detail_title': 'Müraciət detalları',
      'support_status_open': 'Açıq',
      'support_status_resolved': 'Həll edilib',
      // Manual entry
      'store_name': 'Mağaza adı',
      'date_label': 'Tarix',
      'payment_method': 'Ödəniş üsulu',
      'items_label': 'Məhsullar',
      'total_label': 'Cəmi',
      'cash': 'Nağd',
      'card': 'Kart',
      // VAT Tracker
      'no_vat_data': 'Hələlik ÖDV məlumatı yoxdur',
      'vat_scan_hint': 'ÖDV-nizi izləmək üçün ÖDV olan qəbzləri skan edin.',
      'total_vat_paid': 'Cəmi ödənilmiş ÖDV',
      'unclaimed': 'Tələb Edilməmiş',
      'unclaimed_vat': 'Tələb edilməmiş ƏDV',
      'claimed': 'Tələb Edilmiş',
      // Category names
      'cat_meat': 'Et',
      'cat_dairy': 'Süd məhsulları',
      'cat_vegetables': 'Tərəvəz',
      'cat_household': 'Məişət',
      'cat_grocery': 'Məhsul',
      'cat_restaurant': 'Restoran',
      'cat_tobacco': 'Siqaret',
      'cat_transport': 'Nəqliyyat',
      'cat_health': 'Sağlamlıq',
      'cat_clothing': 'Geyim',
      'cat_utilities': 'Kommunal',
      'cat_education': 'Təhsil',
      'cat_other': 'Digər',
      'no_receipts_in_period': 'Bu dövrdə qəbz yoxdur',
      'income_sources': 'Gəlir mənbələri',
      'filter_by_category': 'Kateqoriyaya görə filtr',
      'select_month': 'Ay seçin',
      'select_year': 'İl seçin',
      'confirm': 'Təsdiq et',
      'edit_category': 'Kateqoriyanı redaktə et',
      'pick_icon': 'İkon seçin',
      'pick_color': 'Rəng seçin',
      'select_category': 'Kateqoriya seçin',
      'family_members': 'Ailə üzvləri',
      'currency': 'Valyuta',
      'category': 'Kateqoriya',
      'most_bought_need_more': 'Ən çox aldıqlarınızı görmək üçün daha çox qəbz əlavə edin',
    },
    'ru': {
      // Nav
      'home': 'Главная',
      'receipts': 'Чеки',
      'restock': 'Пополнение',
      'ai_chat': 'Спросить Balanzo',
      'profile': 'Профиль',
      'nav_home': 'Главная',
      'nav_receipts': 'Чеки',
      'nav_restock': 'Склад',
      'nav_ai': 'Balanzo',
      'nav_profile': 'Профиль',
      // Common actions
      'cancel': 'Отмена',
      'retry': 'Повторить',
      'refresh': 'Обновить',
      'save': 'Сохранить',
      'leave': 'Покинуть',
      'claim': 'Получить',
      'add_item': 'Добавить товар',
      'see_all': 'Посмотреть всё',
      'delete': 'Удалить',
      'edit': 'Редактировать',
      // Receipt capture
      'scan_receipt': 'Сканировать чек',
      'manual_entry': 'Ввести вручную',
      'add_receipt': 'Добавить чек',
      'process_receipt': 'Обработать чек',
      'scan_photo_instead': 'Сканировать фото чека',
      'enter_fiscal_manually': 'Ввести Fiscal ID вручную',
      'enter_fiscal_id': 'Введите Fiscal ID',
      'enter_fiscal_hint': 'Введите ID документа из вашего чека e-kassa.',
      'fetch_receipt': 'Получить чек',
      'save_receipt': 'Сохранить чек',
      'saving': 'Сохраняю...',
      'scan_qr_code': 'Сканировать QR-код',
      'scan_ekassa_qr': 'Сканировать e-kassa QR',
      'scan_qr_hint': 'Наведите на QR-код на чеке',
      'take_photo': 'Сделать фото',
      'upload_from_gallery': 'Загрузить из галереи',
      'fetching_receipt': 'Получение чека {id}…',
      'processing_receipt': 'Обработка чека...',
      // Home / Dashboard
      'monthly_spend': 'Расходы за месяц',
      'budget_alerts': 'Бюджетные предупреждения',
      'recent_receipts': 'Последние чеки',
      'vs_last_month': 'к прошлому месяцу',
      'error_loading_data': 'Ошибка загрузки данных',
      'no_receipts_yet': 'Пока нет чеков',
      'scan_to_start': 'Отсканируйте чек для начала',
      'scan_first_receipt': 'Отсканируйте первый чек для начала отслеживания',
      'spent_in': 'потрачено',
      'tab_personal': 'Личные',
      'tab_family': 'Семья',
      'dash_avg_receipt': 'Средний чек',
      'dash_stores': 'Магазины',
      'dash_items': 'Товары',
      'dash_this_week': 'Эта неделя',
      'dash_last_week': 'Прошлая',
      'dash_this_month': 'Этот месяц',
      'dash_last_month': 'Прошлый месяц',
      'dash_last_year_month': 'Тот же месяц год назад',
      'dash_vs_last_month': 'к прошлому месяцу',
      'dash_vs_last_year': 'к тому же месяцу год назад',
      'ai_upgrade': 'Премиум',
      'dash_top_category': 'Топ категория',
      'dash_top_stores': 'Топ магазины',
      'dash_most_bought': 'Покупки',
      'dash_most_often': 'Чаще всего',
      'dash_top_spend_item': 'Крупнейшая',
      'dash_period_fallback': 'В этом месяце пока нет — показано',
      'dash_no_categories': 'Чеки есть, но категории за этот период не найдены.',
      'dash_inflation': 'Изменение цен',
      'dash_most_by_qty': 'По количеству',
      'dash_most_by_value': 'По сумме',
      'dash_qty_unit': 'шт.',
      'dash_category_spend': 'Расход по категории',
      'dash_no_category_items': 'Нет позиций в этой категории.',
      'dash_tap_for_details': 'Нажмите для деталей',
      'budget_section': 'Бюджет',
      'budget_limits': 'Лимиты по категориям',
      'income_total': 'Доход',
      'spend_total': 'Расход',
      'remaining_balance': 'Остаток',
      'family_income_total': 'Доход семьи',
      'family_spend_total': 'Расход семьи',
      'income_editor_title': 'Ваш доход за месяц',
      'income_label': 'Источник (зарплата, подработка…)',
      'income_amount': 'Сумма (AZN)',
      'income_preset_salary': 'Зарплата',
      'income_preset_rent': 'Аренда',
      'income_preset_freelance': 'Фриланс',
      'income_add_source': 'Добавить источник дохода',
      'income_recurring': 'Ежемесячно',
      'income_one_time': 'Только этот месяц',
      'income_type_label': 'Тип дохода',
      'income_edit_source': 'Редактировать источник',
      'income_delete': 'Удалить',
      'duplicate_receipt_title': 'Чек уже сохранён',
      'soft_duplicate_title': 'Похоже, уже есть',
      'soft_duplicate_body': 'Похожий чек из {store} уже сохранён. Сохранить снова?',
      'save_anyway': 'Всё равно сохранить',
      'view_existing': 'Посмотреть существующий',
      'view_receipt': 'Открыть чек',
      'restock_ignore': 'Скрыть',
      'restock_bought': 'Купил',
      'restock_clear': 'Очистить',
      'restock_avg_qty': 'Обыч. кол-во',
      'restock_latest_price': 'Посл. цена',
      'restock_est_budget': 'Примерно',
      'restock_items_due': 'товаров в списке',
      'restock_tap_hint': 'Купил или скрыть',
      'restock_days_overdue': 'дн. просрочки',
      'restock_due_today': 'Сегодня',
      'restock_due_in': 'Через',
      'restock_days': 'дн.',
      'restock_every': 'Каждые',
      'restock_ignored': 'Скрыто',
      'share_shopping_list': 'Поделиться',
      'restock_share_header': 'Список покупок (Balanzo):',
      'restock_share_est_total': 'Примерно всего:',
      // Receipts
      'search_receipts': 'Поиск по названию магазина…',
      'failed_to_load': 'Не удалось загрузить чеки',
      // Restock
      'due_for_restock': 'Пора пополнить запас',
      'marked_as_bought': 'Отмечено как куплено',
      'no_restock_yet': 'Пока нет прогнозов пополнения',
      'restock_scan_hint': 'Сканируйте минимум 2 чека с одинаковыми товарами для прогнозов.',
      // AI Chat
      'ai_assistant': 'Balanzo AI',
      'ai_disclaimer': 'Balanzo AI может ошибаться. Это не финансовый совет. Пожалуйста, перепроверяйте ответы.',
      'ask_spending': 'Спросите о ваших расходах...',
      'thinking': 'Думаю...',
      // Profile
      'profile_settings': 'Профиль и настройки',
      'preferences': 'Предпочтения',
      'subscription': 'Подписка',
      'account': 'Аккаунт',
      'language': 'Язык',
      'notifications': 'Уведомления',
      'notif_empty': 'Уведомлений пока нет',
      'notif_clear': 'Очистить',
      'notif_mark_all_read': 'Отметить все прочитанными',
      'notif_mark_unread': 'Непрочитано',
      'notif_detail_title': 'Уведомление',
      'notif_restock_title': 'Напоминание о пополнении',
      'notif_restock_body': 'Обычно вы покупаете «{itemName}» примерно в это время.',
      'support': 'Поддержка',
      'support_intro': 'Нужна помощь с Balanzo? Нажмите «Сообщить» на чеке — мы получим номер чека и описание проблемы.',
      'support_report_hint': 'Сообщить о проблеме с чеком',
      'support_report_steps': 'Откройте чек, нажмите «Сообщить», опишите проблему и отправьте.',
      'report_receipt': 'Сообщить',
      'report_receipt_title': 'Сообщить о проблеме',
      'report_receipt_hint': 'Опишите проблему (неверные товары, суммы и т.д.)',
      'report_receipt_submit': 'Отправить',
      'report_receipt_success': 'Сообщение отправлено. Спасибо!',
      'report_already_reported': 'Об этом чеке уже сообщали',
      'report_existing_status': 'Статус',
      'report_something_else': 'Сообщить о другом',
      'report_new_title': 'Дополнить обращение',
      'receipt_number': 'Чек №',
      'sign_out': 'Выйти',
      'delete_account': 'Удалить аккаунт',
      'upgrade': 'Получить Premium',
      'upgrade_to_premium': 'Обновить до Premium',
      'upgrade_screen_title': 'Balanzo Premium',
      'upgrade_hero_title': 'Полный доступ к Balanzo',
      'upgrade_hero_subtitle': 'AI-аналитика, семейный доступ и многое другое',
      'upgrade_choose_plan': 'Выберите план',
      'upgrade_free_forever': 'Бесплатно — навсегда',
      'upgrade_most_popular': 'Популярный',
      'upgrade_monthly': 'Месяц',
      'upgrade_annual': 'Год',
      'upgrade_save_16': '−16%',
      'upgrade_now': 'Оформить Premium',
      'upgrade_cancel_note': 'Отмена в любое время. Безопасная оплата.',
      'upgrade_success': 'Подписка обновлена! Приятного использования Premium.',
      'get_premium': 'Получить Premium',
      'free_plan': 'Бесплатный план',
      'ai_premium': 'AI Premium',
      'family_plan': 'Семейный план',
      'share_my_stats': 'Поделиться статистикой',
      // Categories & settings
      'categories': 'Категории',
      'new_category': 'Новая категория',
      'category_name_label': 'Название категории',
      'category_default': 'По умолчанию',
      'add_category': 'Добавить',
      'error_generic': 'Ошибка',
      'ai_assistant_unavailable': 'AI ассистент сейчас недоступен.',
      'ai_premium_messages_left': 'Осталось {count} сообщ. в этом месяце',
      'ai_premium_limit_reached': 'Месячный лимит исчерпан ({limit} сообщ.). Сброс {resetDate}.',
      'ai_premium_limit_title': 'Достигнут месячный лимит AI',
      'ai_free_limit_title': 'Бесплатно: 1 сообщение в неделю',
      'ai_free_limit_body': 'Оформите Premium для большего числа сообщений, 90 дней истории расходов и полной AI-аналитики.',
      'ai_maybe_later': 'Позже',
      'ai_response_error': 'Извините, сейчас не удалось получить ответ.',
      'ai_network_error': 'Ошибка сети. Попробуйте снова.',
      'sign_in_title': 'Войти или создать аккаунт',
      'sign_in_subtitle': 'Выберите способ входа',
      'sign_in_terms': 'Продолжая, вы соглашаетесь с Условиями использования и Политикой конфиденциальности',
      'app_tagline': 'Семейный бюджет — просто',
      'continue_with_google': 'Продолжить с Google',
      'continue_with_apple': 'Продолжить с Apple',
      'sign_in_cancelled': 'Вход отменён.',
      'sign_in_rejected': 'Сервер отклонил вход. Проверьте настройки провайдера в Supabase Auth.',
      'sign_in_google_config': 'Google Sign-In не настроен для этой сборки (SHA-1 / Firebase).',
      'sign_in_network': 'Не удаётся связаться с сервером. Проверьте Wi‑Fi или мобильный интернет.',
      'fiscal_document_id': 'Фискальный ID документа',
      'fiscal_id_hint': 'E7av3BYTEgRV или полный URL QR',
      'fiscal_id_help': 'Найдите этот ID на бумажном чеке или в письме с подтверждением.',
      'fiscal_id_required': 'Введите фискальный ID документа',
      'fiscal_ekassa_note': 'Чеки по фискальному ID проверяются напрямую в государственной базе e-kassa Азербайджана.',
      'photo_hint_top': 'Начните с верха чека',
      'photo_hint_middle': 'Немного перекрывайте — снимите середину',
      'photo_hint_bottom': 'Снимите нижнюю часть чека',
      'photo_hint_more': 'Добавьте ещё фрагменты или нажмите «Обработать».',
      'analytics': 'Аналитика',
      'vat_tracker': 'НДС Трекер',
      'privacy_policy': 'Политика конфиденциальности',
      'terms': 'Условия использования',
      'about': 'О приложении',
      'settings': 'Настройки',
      'last_7_days': 'Показаны последние 7 дней · Получить Premium',
      'last_30_days': 'Показаны последние 30 дней · Получить Premium',
      // Family
      'family': 'Семья',
      'no_family_yet': 'Семьи пока нет',
      'no_family_desc': 'Создайте семью для совместного отслеживания расходов и бюджета.',
      'create_family': 'Создать семью',
      'leave_family': 'Покинуть семью',
      'add_member': 'Добавить участника',
      'members': 'Участники',
      'combined_spend': 'Совместные расходы этого месяца',
      'family_available_budget': 'Доступный бюджет',
      'family_spent_label': 'Потрачено',
      'family_budget_not_set': 'Не задан',
      'family_admin_badge_hint': 'Администратор семьи',
      'share_personal_budget_with_family': 'Показывать личный бюджет семье',
      'share_personal_budget_hint': 'Если включено, члены семьи увидят ваш личный бюджет на вкладке «Семья».',
      'family_member_spend': 'Потрачено',
      'family_member_limit': 'Лимит',
      'invite_whatsapp': 'Пригласить через WhatsApp',
      'whatsapp_invite_message':
          'Присоединяйтесь к семье {familyName} в Balanzo!\n\nНажмите, чтобы вступить:\n{inviteLink}\n\nИли сначала установите приложение:\nhttps://balanzo.app',
      'family_invite_invalid': 'Ссылка-приглашение недействительна.',
      'family_invite_expired': 'Срок приглашения истёк. Попросите новое.',
      'family_invite_error_generic': 'Не удалось вступить в семью. Попробуйте снова.',
      'family_invite_joined_title': 'Добро пожаловать в семью',
      'family_invite_success_generic': 'Вы вступили в семью.',
      'family_name_hint': 'Название семьи (напр. семья Əliyev)',
      'phone_number_label': 'Номер телефона',
      'leave_family_confirm': 'Вы уверены, что хотите покинуть эту семью?',
      'family_role_admin': 'Админ',
      'family_role_co_admin': 'Со-админ',
      'family_role_member': 'Участник',
      'family_relationship_label': 'Родство',
      'family_relationship_unset': 'Не указано',
      'family_relationship_father': 'Отец',
      'family_relationship_mother': 'Мать',
      'family_relationship_son': 'Сын',
      'family_relationship_daughter': 'Дочь',
      'family_relationship_spouse': 'Супруг(а)',
      'family_relationship_sibling': 'Брат/сестра',
      'family_relationship_other': 'Другое',
      'spend_limit': 'Лимит расходов',
      'set_spend_limit': 'Установить лимит',
      'spend_limit_confirm': 'Подтвердить лимит',
      'spend_limit_pending': 'Ожидающий лимит: {amount} AZN',
      'spend_limit_proposed_hint': 'Админ предложил новый лимит расходов',
      'spend_limit_locked_reason':
          'Лимит установлен в этом месяце и не может быть изменён до следующего месяца.',
      'support_no_reports': 'Обращений пока нет. Нажмите «Сообщить» на чеке, чтобы связаться с нами.',
      'support_detail_title': 'Детали обращения',
      'support_status_open': 'Открыто',
      'support_status_resolved': 'Решено',
      // Manual entry
      'store_name': 'Название магазина',
      'date_label': 'Дата',
      'payment_method': 'Способ оплаты',
      'items_label': 'Товары',
      'total_label': 'Итого',
      'cash': 'Наличные',
      'card': 'Карта',
      // VAT Tracker
      'no_vat_data': 'Данных НДС пока нет',
      'vat_scan_hint': 'Сканируйте чеки с НДС для отслеживания НДС к возврату.',
      'total_vat_paid': 'Всего уплачено НДС',
      'unclaimed': 'Незаявленный',
      'unclaimed_vat': 'Незаявленный НДС',
      'claimed': 'Заявленный',
      // Category names
      'cat_meat': 'Мясо',
      'cat_dairy': 'Молочные',
      'cat_vegetables': 'Овощи',
      'cat_household': 'Бытовые',
      'cat_grocery': 'Продукты',
      'cat_restaurant': 'Рестораны',
      'cat_tobacco': 'Табак',
      'cat_transport': 'Транспорт',
      'cat_health': 'Здоровье',
      'cat_clothing': 'Одежда',
      'cat_utilities': 'Коммунальные',
      'cat_education': 'Образование',
      'cat_other': 'Другое',
      'no_receipts_in_period': 'Нет чеков за этот период',
      'income_sources': 'Источники дохода',
      'filter_by_category': 'Фильтр по категории',
      'select_month': 'Выберите месяц',
      'select_year': 'Выберите год',
      'confirm': 'Подтвердить',
      'edit_category': 'Редактировать категорию',
      'pick_icon': 'Выберите значок',
      'pick_color': 'Выберите цвет',
      'select_category': 'Выберите категорию',
      'family_members': 'Члены семьи',
      'currency': 'Валюта',
      'category': 'Категория',
      'most_bought_need_more': 'Добавьте больше чеков, чтобы увидеть самые частые покупки',
    },
  };

  static String get(String key, String locale) {
    return _strings[locale]?[key] ?? _strings['en']?[key] ?? key;
  }

  static const familyRelationshipKeys = [
    'father',
    'mother',
    'son',
    'daughter',
    'spouse',
    'sibling',
    'other',
  ];

  static String familyRole(String role, String locale) {
    switch (role) {
      case 'admin':
        return get('family_role_admin', locale);
      case 'co_admin':
        return get('family_role_co_admin', locale);
      default:
        return get('family_role_member', locale);
    }
  }

  static String familyRelationship(String? relationship, String locale) {
    if (relationship == null || relationship.isEmpty) {
      return get('family_relationship_unset', locale);
    }
    return get('family_relationship_$relationship', locale);
  }

  static String notifRestockBody(String itemName, String locale) {
    return get('notif_restock_body', locale).replaceAll('{itemName}', itemName);
  }

  static String whatsAppInviteMessage(
    String familyName,
    String inviteLink,
    String locale,
  ) {
    return get('whatsapp_invite_message', locale)
        .replaceAll('{familyName}', familyName)
        .replaceAll('{inviteLink}', inviteLink);
  }

  static String familyInviteSuccess(String familyName, String locale) {
    switch (locale) {
      case 'az':
        return '$familyName ailəsinə qoşuldunuz!';
      case 'ru':
        return 'Вы вступили в семью «$familyName»!';
      default:
        return 'You joined $familyName!';
    }
  }

  static String spendLimitPending(String amount, String locale) {
    return get('spend_limit_pending', locale).replaceAll('{amount}', amount);
  }

  static String warmGreeting(String firstName, String locale) {
    switch (locale) {
      case 'az':
        return 'Xoş gəldin, $firstName!';
      case 'ru':
        return 'Рад тебя видеть, $firstName!';
      default:
        return 'Welcome back, $firstName!';
    }
  }

  static String receiptsThisMonth(int count, String locale) {
    switch (locale) {
      case 'az':
        return count == 1
            ? 'Bu ay 1 çek skan edilib'
            : 'Bu ay $count çek skan edilib';
      case 'ru':
        return count == 1
            ? '1 чек отсканирован в этом месяце'
            : '$count чеков отсканировано в этом месяце';
      default:
        return count == 1
            ? '1 receipt scanned this month'
            : '$count receipts scanned this month';
    }
  }

  static String vsLastMonthDiff(double diff, String locale) {
    final sign = diff >= 0 ? '+' : '';
    final amount = '$sign${diff.toStringAsFixed(2)} AZN';
    switch (locale) {
      case 'az':
        return '$amount keçən aya nisbətən';
      case 'ru':
        return '$amount к прошлому месяцу';
      default:
        return '$amount vs last month';
    }
  }

  static String visitCount(int count, String locale) {
    switch (locale) {
      case 'az':
        return count == 1 ? '1 dəfə' : '$count dəfə';
      case 'ru':
        return count == 1 ? '1 визит' : '$count визитов';
      default:
        return count == 1 ? '1 visit' : '$count visits';
    }
  }

  static String purchaseCount(int count, String locale) {
    switch (locale) {
      case 'az':
        return count == 1 ? '1 dəfə alınıb' : '$count dəfə alınıb';
      case 'ru':
        return count == 1 ? '1 покупка' : '$count покупок';
      default:
        return count == 1 ? '1 purchase' : '$count purchases';
    }
  }

  static String familySetupHint(String locale) {
    switch (locale) {
      case 'az':
        return 'Ailə interfeysini görmək üçün ailəyə qoşulun və ya yeni ailə yaradın — Profil bölməsində edə bilərsiniz.';
      case 'ru':
        return 'Чтобы открыть семейный режим, создайте семью или вступите в существующую — это можно сделать в разделе «Профиль».';
      default:
        return 'To see the family view, join a family or create one — you can do this in Profile.';
    }
  }

  static String softDuplicateBody(String store, String locale) {
    return get('soft_duplicate_body', locale).replaceAll('{store}', store);
  }

  static String duplicateReceiptBody(
    String scanner,
    String store,
    String locale,
  ) {
    switch (locale) {
      case 'az':
        return 'Bu qəbz artıq $scanner tərəfindən skan edilib ($store).';
      case 'ru':
        return 'Этот чек уже добавил(а) $scanner ($store).';
      default:
        return 'This receipt was already scanned by $scanner ($store).';
    }
  }

  static String categoryName(String englishName, String locale) {
    const keys = {
      'Grocery': 'cat_grocery',
      'Restaurant': 'cat_restaurant',
      'Tobacco': 'cat_tobacco',
      'Transport': 'cat_transport',
      'Health': 'cat_health',
      'Clothing': 'cat_clothing',
      'Utilities': 'cat_utilities',
      'Education': 'cat_education',
      'Other': 'cat_other',
      'Meat': 'cat_meat',
      'Dairy': 'cat_dairy',
      'Vegetables': 'cat_vegetables',
      'Household': 'cat_household',
    };
    final key = keys[englishName];
    if (key != null) return get(key, locale);
    return englishName;
  }

  static String receiptsInPeriod(int count, int month, int year, String locale) {
    switch (locale) {
      case 'az':
        return count == 1
            ? 'Bu dövrdə 1 qəbz'
            : 'Bu dövrdə $count qəbz';
      case 'ru':
        return count == 1
            ? '1 чек за период'
            : '$count чеков за период';
      default:
        return count == 1
            ? '1 receipt in this period'
            : '$count receipts in this period';
    }
  }

  static String familyEmptyHint(String locale) {
    switch (locale) {
      case 'az':
        return 'Ailə qəbzləri yoxdur. Paylaşmaq üçün qəbz saxlayarkən Ailə seçin.';
      case 'ru':
        return 'Нет семейных чеков. Сохраняйте чек как «Семья».';
      default:
        return 'No family receipts yet. Save a receipt as Family to share.';
    }
  }

  static String periodFallbackNotice(int month, int year, String locale) {
    final label = spentInMonth(month, year, locale);
    switch (locale) {
      case 'az':
        return '${get('dash_period_fallback', locale)}: $label';
      case 'ru':
        return '${get('dash_period_fallback', locale)}: $label';
      default:
        return '${get('dash_period_fallback', locale)} $label';
    }
  }

  static String greeting(String name, String locale) {
    switch (locale) {
      case 'az': return 'Salam, $name!';
      case 'ru': return 'Привет, $name!';
      default:   return 'Hello, $name!';
    }
  }

  static String spentInMonth(int month, int year, String locale) {
    final m = _monthName(month, locale);
    switch (locale) {
      case 'az': return '$m $year-da xərcləndi';
      case 'ru': return 'Потрачено в $m $year';
      default:   return 'Spent in $m $year';
    }
  }

  static String monthName(int month, String locale) {
    const en = ['','January','February','March','April','May','June','July','August','September','October','November','December'];
    const az = ['','Yanvar','Fevral','Mart','Aprel','May','İyun','İyul','Avqust','Sentyabr','Oktyabr','Noyabr','Dekabr'];
    const ru = ['','Январь','Февраль','Март','Апрель','Май','Июнь','Июль','Август','Сентябрь','Октябрь','Ноябрь','Декабрь'];
    if (month < 1 || month > 12) return '';
    switch (locale) {
      case 'az': return az[month];
      case 'ru': return ru[month];
      default:   return en[month];
    }
  }

  static String monthShortName(int month, String locale) {
    const en = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const az = ['','Yan','Fev','Mar','Apr','May','İyn','İyl','Avq','Sen','Okt','Noy','Dek'];
    const ru = ['','янв','фев','мар','апр','май','июн','июл','авг','сен','окт','ноя','дек'];
    if (month < 1 || month > 12) return '';
    switch (locale) {
      case 'az': return az[month];
      case 'ru': return ru[month];
      default:   return en[month];
    }
  }

  static String _monthName(int month, String locale) {
    const en = ['','January','February','March','April','May','June','July','August','September','October','November','December'];
    const az = ['','Yanvar','Fevral','Mart','Aprel','May','İyun','İyul','Avqust','Sentyabr','Oktyabr','Noyabr','Dekabr'];
    const ru = ['','январе','феврале','марте','апреле','мае','июне','июле','августе','сентябре','октябре','ноябре','декабре'];
    if (month < 1 || month > 12) return '';
    switch (locale) {
      case 'az': return az[month];
      case 'ru': return ru[month];
      default:   return en[month];
    }
  }

  static List<String> aiQuickQuestions(String locale) {
    switch (locale) {
      case 'az':
        return [
          'Bu ay büdcəmi aşacağammı?',
          'Bu ay zülala nə qədər xərclədim?',
          'Xərclərim niyə artdı?',
          'Bu il nə qədər ƏDV qazanacağam?',
        ];
      case 'ru':
        return [
          'Превышу ли я бюджет в этом месяце?',
          'Сколько я потратил на белок?',
          'Почему выросли расходы?',
          'Сколько НДС я сэкономлю?',
        ];
      default:
        return [
          'Will I exceed my budget this month?',
          'How much did I spend on protein this month?',
          'What caused my spending to increase?',
          'How much VAT will I save this year?',
        ];
    }
  }

  static List<String> upgradeFreeFeatures(String locale) {
    switch (locale) {
      case 'az':
        return [
          'Limitsiz qəbz skan',
          'AI — son 7 günün məlumatı',
          'Həftədə 1 AI sual',
          'Əsas panel',
          'Yenidən alış xatırlatmaları',
        ];
      case 'ru':
        return [
          'Безлимитное сканирование чеков',
          'AI — данные за 7 дней',
          '1 AI-вопрос в неделю',
          'Базовая панель',
          'Напоминания о покупках',
        ];
      default:
        return [
          'Unlimited receipt scanning',
          'AI chat — last 7 days data',
          '1 AI question per week',
          'Basic dashboard',
          'Restock reminders',
        ];
    }
  }

  static List<String> upgradeAiPremiumFeatures(String locale) {
    switch (locale) {
      case 'az':
        return [
          'Limitsiz qəbz skan',
          'Limitsiz AI suallar',
          'Qiymət anomaliyası xəbərdarlıqları',
          'PDF ixrac',
          'Prioritet dəstək',
        ];
      case 'ru':
        return [
          'Безлимитное сканирование',
          'Безлимитные AI-вопросы',
          'Оповещения о ценах',
          'Экспорт в PDF',
          'Приоритетная поддержка',
        ];
      default:
        return [
          'Unlimited receipt scanning',
          'Unlimited AI questions',
          'Price anomaly alerts',
          'Export to PDF',
          'Priority support',
        ];
    }
  }

  static List<String> upgradeFamilyFeatures(String locale) {
    switch (locale) {
      case 'az':
        return [
          'AI Premium-dakı hər şey',
          '6 ailə üzvünə qədər',
          'Ortaq büdcə izləmə',
          'Ailə xərc analitikası',
        ];
      case 'ru':
        return [
          'Всё из AI Premium',
          'До 6 членов семьи',
          'Общий бюджет',
          'Семейная аналитика',
        ];
      default:
        return [
          'Everything in AI Premium',
          'Up to 6 family members',
          'Shared budget tracking',
          'Family spending insights',
        ];
    }
  }

  static String aiGreeting(String locale) {
    switch (locale) {
      case 'az':
        return 'Salam! Mən Balanzo AI köməkçisiyəm. Xərcləriniz haqqında hər şeyi soruşun.';
      case 'ru':
        return 'Привет! Я ваш AI-ассистент Balanzo. Спросите меня всё о ваших расходах.';
      default:
        return "Hi! I'm your Balanzo AI assistant. Ask me anything about your spending.";
    }
  }

  static String aiUpgradeLimitReached(String locale) {
    switch (locale) {
      case 'az':
        return 'Pulsuz plan: həftədə 1 mesaj. Limitsiz AI üçün yüksəldin.';
      case 'ru':
        return 'Бесплатно: 1 сообщение в неделю. Оформите Premium для безлимита.';
      default:
        return 'Free tier: 1 message per week. Upgrade for unlimited AI.';
    }
  }

  static String aiUpgradeBanner(int dataWindowDays, int freeLeft, String locale) {
    switch (locale) {
      case 'az':
        return 'Son $dataWindowDays günün məlumatı · $freeLeft pulsuz mesaj qaldı';
      case 'ru':
        return 'Данные за $dataWindowDays дн. · осталось $freeLeft бесплатных сообщ.';
      default:
        final msgWord = freeLeft == 1 ? 'message' : 'messages';
        return 'Last $dataWindowDays days of data · $freeLeft free $msgWord left';
    }
  }

  static String aiPremiumMessagesLeft(int left, String locale) {
    return get('ai_premium_messages_left', locale).replaceAll('{count}', '$left');
  }

  static String aiPremiumLimitReached(DateTime? resetsOn, String locale, {int limit = 20}) {
    final resetDate = _formatResetDate(resetsOn, locale);
    return get('ai_premium_limit_reached', locale)
        .replaceAll('{limit}', '$limit')
        .replaceAll('{resetDate}', resetDate);
  }

  static String _formatResetDate(DateTime? date, String locale) {
    if (date == null) return '';
    final day = date.day;
    final month = _monthName(date.month, locale);
    final year = date.year;
    switch (locale) {
      case 'az':
        return '$day $month $year';
      case 'ru':
        return '$day $month $year г.';
      default:
        return '$month $day, $year';
    }
  }

  static String productBuysThisPeriod(int buys, double totalQty, String locale) {
    final qty = totalQty == totalQty.roundToDouble()
        ? totalQty.toStringAsFixed(0)
        : totalQty.toStringAsFixed(1);
    switch (locale) {
      case 'az':
        return '$buys alış bu ay, cəmi $qty ${get('dash_qty_unit', locale)}';
      case 'ru':
        return '$buys покупок в этом месяце, всего $qty ${get('dash_qty_unit', locale)}';
      default:
        return '$buys buys this month, $qty ${get('dash_qty_unit', locale)} total';
    }
  }

  static String productPeriodSummary(int buys, double totalQty, String locale) {
    final qty = totalQty == totalQty.roundToDouble()
        ? totalQty.toStringAsFixed(0)
        : totalQty.toStringAsFixed(1);
    switch (locale) {
      case 'az':
        return '$buys alış, cəmi $qty ${get('dash_qty_unit', locale)}';
      case 'ru':
        return '$buys покупок, всего $qty ${get('dash_qty_unit', locale)}';
      default:
        return '$buys buys, $qty ${get('dash_qty_unit', locale)} total';
    }
  }
}
