/* Shared membership translations. Source text is retained for safe fallback. */
(()=>{'use strict';
const languages=['tr','en','de','ru','fr','zh'];
const rows=`
Üyelik doğrulama durumu|Membership verification status|Verifizierungsstatus|Статус проверки регистрации|Statut de vérification du compte|会员验证状态
WhatsApp mesajı teslim edildi. Telefonunuzu gelen kodla doğrulayın.|WhatsApp message delivered. Verify your phone with the code.|WhatsApp-Nachricht zugestellt. Bestätigen Sie Ihr Telefon mit dem Code.|Сообщение WhatsApp доставлено. Подтвердите телефон кодом.|Message WhatsApp livré. Vérifiez votre téléphone avec le code.|WhatsApp消息已送达，请使用验证码验证电话。
Başvurunuz incelemede. Sonuç hesabınızda ve e-posta bildirimiyle paylaşılacak.|Your application is under review. The result will appear in your account and by email.|Ihr Antrag wird geprüft. Das Ergebnis erscheint im Konto und per E-Mail.|Заявка на рассмотрении. Результат появится в аккаунте и по почте.|Votre demande est en cours d’examen. Le résultat sera disponible dans votre compte et par e-mail.|您的申请正在审核，结果将在账户和电子邮件中通知。
Yönetici açıklamasını inceleyip kimlik bilgilerinizi yeniden gönderin.|Read the administrator’s feedback and resubmit your identity details.|Lesen Sie die Rückmeldung und senden Sie Ihre Identitätsdaten erneut.|Прочитайте комментарий администратора и повторно отправьте данные.|Consultez le commentaire et renvoyez vos informations d’identité.|请查看管理员说明并重新提交身份信息。
Sonraki adım: Telefonunuza gelen WhatsApp kodunu doğrulayın.|Next step: Verify the WhatsApp code sent to your phone.|Nächster Schritt: Bestätigen Sie den WhatsApp-Code.|Следующий шаг: подтвердите код WhatsApp на телефоне.|Prochaine étape : vérifiez le code WhatsApp reçu.|下一步：验证手机收到的WhatsApp验证码。
Üyelik doğrulama adımlarınız tamamlandı.|Your membership verification steps are complete.|Ihre Verifizierung ist abgeschlossen.|Все этапы проверки завершены.|Les étapes de vérification sont terminées.|您的会员验证步骤已完成。
Sonraki adım: Kimlik bilgilerinizi incelemeye gönderin.|Next step: Submit your identity details for review.|Nächster Schritt: Identitätsdaten zur Prüfung senden.|Следующий шаг: отправьте данные личности на проверку.|Prochaine étape : envoyez vos informations d’identité.|下一步：提交身份信息以供审核。

Üye olun|Create an account|Konto erstellen|Создать аккаунт|Créer un compte|创建账户
Hesabınıza giriş yapın|Sign in to your account|Bei Ihrem Konto anmelden|Войти в аккаунт|Connectez-vous à votre compte|登录账户
Doğrulama kodunu girin|Enter verification code|Bestätigungscode eingeben|Введите код подтверждения|Saisissez le code de vérification|输入验证码
E-postanızı doğrulayın|Verify your email|E-Mail bestätigen|Подтвердите почту|Vérifiez votre adresse e-mail|验证邮箱
Parolanızı yenileyin|Reset your password|Passwort zurücksetzen|Восстановите пароль|Réinitialisez votre mot de passe|重置密码
Ad soyad|Full name|Vollständiger Name|Имя и фамилия|Nom et prénom|姓名
E-posta|Email|E-Mail|Электронная почта|E-mail|电子邮箱
Telefon (ülke koduyla)|Phone (with country code)|Telefon (mit Ländervorwahl)|Телефон (с кодом страны)|Téléphone (avec indicatif)|电话（含国家代码）
Doğrulama kodu iste|Request verification code|Bestätigungscode anfordern|Запросить код подтверждения|Demander un code de vérification|获取验证码
Doğrulama kodu|Verification code|Bestätigungscode|Код подтверждения|Code de vérification|验证码
Yeni parola|New password|Neues Passwort|Новый пароль|Nouveau mot de passe|新密码
Parola|Password|Passwort|Пароль|Mot de passe|密码
Mevcut parola|Current password|Aktuelles Passwort|Текущий пароль|Mot de passe actuel|当前密码
Göster|Show|Anzeigen|Показать|Afficher|显示
Gizle|Hide|Ausblenden|Скрыть|Masquer|隐藏
Parolayı göster|Show password|Passwort anzeigen|Показать пароль|Afficher le mot de passe|显示密码
En az 12 karakter kullanın.|Use at least 12 characters.|Verwenden Sie mindestens 12 Zeichen.|Используйте не менее 12 символов.|Utilisez au moins 12 caractères.|至少使用12个字符。
Hesap oluştur|Create account|Konto erstellen|Создать аккаунт|Créer un compte|创建账户
Doğrula|Verify|Bestätigen|Подтвердить|Vérifier|验证
Yenileme kodu iste|Request reset code|Code anfordern|Запросить код восстановления|Demander un code|获取重置码
Giriş yap|Sign in|Anmelden|Войти|Se connecter|登录
Üye ol|Register|Registrieren|Регистрация|S’inscrire|注册
Kodu yeniden gönder|Resend code|Code erneut senden|Отправить код повторно|Renvoyer le code|重新发送验证码
Parolamı unuttum|Forgot password|Passwort vergessen|Забыли пароль|Mot de passe oublié|忘记密码
Zaten üye misiniz?|Already a member?|Bereits registriert?|Уже зарегистрированы?|Déjà membre ?|已有账户？
Henüz üye değil misiniz?|No account yet?|Noch kein Konto?|Нет аккаунта?|Pas encore de compte ?|还没有账户？
Ana sayfaya dön|Back to home|Zur Startseite|На главную|Retour à l’accueil|返回首页
Metinleri incele|Read the documents|Dokumente lesen|Прочитать документы|Lire les documents|阅读条款
Üyelik sözleşmesini kabul ediyorum ve kişisel veri aydınlatma metnini okudum.|I accept the membership agreement and have read the privacy notice.|Ich akzeptiere die Mitgliedschaftsvereinbarung und habe die Datenschutzhinweise gelesen.|Я принимаю условия регистрации и ознакомился с уведомлением о конфиденциальности.|J’accepte les conditions d’adhésion et j’ai lu la notice de confidentialité.|我接受会员协议并已阅读隐私声明。
Kimlik onayı yönetici incelemesiyle yapılır. NVİ/KPS doğrulaması henüz etkin değildir.|Identity approval is reviewed by an administrator. NVİ/KPS verification is not enabled yet.|Die Identitätsprüfung erfolgt durch einen Administrator. NVİ/KPS ist noch nicht aktiviert.|Личность проверяет администратор. Проверка NVİ/KPS пока не включена.|L’identité est examinée par un administrateur. NVİ/KPS n’est pas encore activé.|身份由管理员审核。NVİ/KPS验证尚未启用。
SEYAHATİNİZİN HER ADIMINDA|AT EVERY STEP OF YOUR JOURNEY|BEI JEDEM SCHRITT IHRER REISE|НА КАЖДОМ ЭТАПЕ ПУТЕШЕСТВИЯ|À CHAQUE ÉTAPE DE VOTRE VOYAGE|伴随旅程每一步
Planlarınız ve hesabınız tek yerde.|Your plans and account in one place.|Ihre Pläne und Ihr Konto an einem Ort.|Ваши планы и аккаунт в одном месте.|Vos projets et votre compte au même endroit.|行程与账户，尽在一处。
Rezervasyonlarınızı takip edin, favorilerinizi saklayın ve seyahat bilgilerinizi yönetin.|Track bookings, save favourites and manage travel details.|Buchungen verfolgen, Favoriten speichern und Reisedaten verwalten.|Отслеживайте бронирования, сохраняйте избранное и управляйте поездками.|Suivez vos réservations, gardez vos favoris et gérez vos voyages.|跟踪预订，保存收藏，管理旅行信息。
Rezervasyon ve ödeme takibi|Booking and payment tracking|Buchungs- und Zahlungsübersicht|Бронирования и платежи|Suivi des réservations et paiements|预订与支付跟踪
E-posta ve telefon doğrulama durumları|Email and phone verification|E-Mail- und Telefonbestätigung|Подтверждение почты и телефона|Vérification de l’e-mail et du téléphone|邮箱和电话验证
Yönetici incelemesiyle kimlik onayı|Identity approval by administrator|Identitätsprüfung durch Administrator|Проверка личности администратором|Vérification d’identité par administrateur|管理员身份审核
E-posta gönderimi başarılı olduğunda kod adresinize ulaşır. Kod 10 dakika geçerlidir.|The code arrives after successful email delivery. It is valid for 10 minutes.|Der Code kommt nach erfolgreichem E-Mail-Versand und gilt 10 Minuten.|Код придёт после отправки письма и действителен 10 минут.|Le code arrive après l’envoi de l’e-mail et reste valide 10 minutes.|邮件发送成功后您将收到验证码，有效期为10分钟。
Bilgilerinizi doldurun; doğrulama adımlarını hesabınızdan takip edin.|Enter your details and follow verification in your account.|Geben Sie Ihre Daten ein und verfolgen Sie die Bestätigung im Konto.|Введите данные и следите за подтверждением в аккаунте.|Renseignez vos données et suivez la vérification dans votre compte.|填写资料，在账户中跟踪验证步骤。
Kayıtlı adresiniz için parola yenileme kodu isteyin.|Request a password reset code for your registered email.|Fordern Sie einen Code für Ihre registrierte E-Mail an.|Запросите код восстановления на зарегистрированную почту.|Demandez un code pour votre adresse e-mail enregistrée.|为已注册邮箱获取密码重置码。
Seyahatlerinizi kaldığınız yerden yönetmeye devam edin.|Continue managing your travel plans.|Verwalten Sie Ihre Reisepläne weiter.|Продолжайте управлять поездками.|Continuez à gérer vos voyages.|继续管理您的旅行。
Uygun bir hesap varsa kod gönderim kuyruğuna alındı.|If an eligible account exists, the code was queued.|Bei einem passenden Konto wurde der Code vorgemerkt.|Если аккаунт существует, код поставлен в очередь.|Si un compte admissible existe, le code est en attente d’envoi.|若存在符合条件的账户，验证码已进入发送队列。
Önce e-posta adresinizi doğrulayın.|Verify your email first.|Bestätigen Sie zuerst Ihre E-Mail.|Сначала подтвердите почту.|Vérifiez d’abord votre e-mail.|请先验证邮箱。
İşlem tamamlandı. Hesabınıza giriş yapabilirsiniz.|Completed. You can sign in.|Abgeschlossen. Sie können sich anmelden.|Готово. Вы можете войти.|Terminé. Vous pouvez vous connecter.|操作完成，可以登录账户。
Üyelik sözleşmesi ve gizlilik metni henüz yayınlanmamış. Lütfen acenteyle iletişime geçin.|Membership and privacy documents are not published yet. Contact the agency.|Die Mitgliedschafts- und Datenschutztexte fehlen noch. Kontaktieren Sie die Agentur.|Условия регистрации и конфиденциальности ещё не опубликованы. Свяжитесь с агентством.|Les conditions et la notice de confidentialité ne sont pas encore publiées. Contactez l’agence.|会员与隐私条款尚未发布，请联系旅行社。
Kod hatalı, süresi dolmuş veya deneme sınırı aşılmış.|Code incorrect, expired or attempt limit reached.|Code falsch, abgelaufen oder Versuchslimit erreicht.|Код неверен, истёк или превышен лимит попыток.|Code incorrect, expiré ou limite atteinte.|验证码错误、过期或超出尝试次数。
Bilgilerinizi kontrol edin.|Check your details.|Prüfen Sie Ihre Angaben.|Проверьте данные.|Vérifiez vos données.|请检查您的资料。
İşlem tamamlanamadı.|Unable to complete the request.|Anfrage konnte nicht abgeschlossen werden.|Не удалось выполнить запрос.|Impossible de terminer la demande.|无法完成操作。
İşlem tamamlanamadı. Lütfen tekrar deneyin.|Unable to complete the request. Try again.|Anfrage fehlgeschlagen. Versuchen Sie es erneut.|Не удалось выполнить запрос. Повторите попытку.|La demande a échoué. Réessayez.|操作失败，请重试。
Doğrulama ve güvenlik|Verification and security|Bestätigung und Sicherheit|Подтверждение и безопасность|Vérification et sécurité|验证与安全
Bilgi bekleniyor|Awaiting details|Angaben ausstehend|Ожидаются данные|Informations attendues|等待资料
Yönetici incelemesi bekleniyor|Awaiting administrator review|Warten auf Administratorprüfung|Ожидает проверки администратора|En attente d’examen|等待管理员审核
Yönetici tarafından onaylandı|Approved by administrator|Vom Administrator genehmigt|Одобрено администратором|Approuvé par l’administrateur|管理员已批准
Yeniden inceleme gerekli|Review required|Erneute Prüfung erforderlich|Требуется повторная проверка|Nouvel examen requis|需要重新审核
NVİ doğrulandı|NVİ verified|NVİ bestätigt|Подтверждено NVİ|Vérifié par NVİ|NVİ已验证
Doğrulandı|Verified|Bestätigt|Подтверждено|Vérifié|已验证
Doğrulanmadı|Not verified|Nicht bestätigt|Не подтверждено|Non vérifié|未验证
Telefon|Phone|Telefon|Телефон|Téléphone|电话
Kimlik bilgileriniz yönetici tarafından incelenir. Tam T.C. numaranız saklanmaz.|An administrator reviews your identity details. Your full Turkish ID number is not stored.|Ein Administrator prüft Ihre Identitätsdaten. Die vollständige türkische ID wird nicht gespeichert.|Администратор проверяет ваши данные. Полный номер турецкого удостоверения не сохраняется.|Un administrateur examine vos données. Le numéro d’identité turc complet n’est pas conservé.|管理员审核身份资料，不保存完整土耳其身份证号。
T.C. kimlik numarası|Turkish identity number|Türkische Identitätsnummer|Турецкий идентификационный номер|Numéro d’identité turc|土耳其身份证号
Doğum tarihi|Date of birth|Geburtsdatum|Дата рождения|Date de naissance|出生日期
İncelemeye gönder|Submit for review|Zur Prüfung senden|Отправить на проверку|Envoyer pour examen|提交审核
E-posta doğrulama kodu iste|Request email verification code|E-Mail-Code anfordern|Запросить код подтверждения почты|Demander un code e-mail|获取邮箱验证码
Parolamı yenile|Reset my password|Passwort zurücksetzen|Восстановить пароль|Réinitialiser mon mot de passe|重置密码
Diğer oturumlardan çıkış yap|Sign out other sessions|Andere Sitzungen abmelden|Завершить другие сеансы|Déconnecter les autres sessions|退出其他会话
Telefon doğrulaması|Phone verification|Telefonbestätigung|Подтверждение телефона|Vérification du téléphone|电话验证
Kodu WhatsApp ile gönder|Send code via WhatsApp|Code per WhatsApp senden|Отправить код через WhatsApp|Envoyer le code par WhatsApp|通过WhatsApp发送验证码
WhatsApp doğrulama kodu|WhatsApp verification code|WhatsApp-Bestätigungscode|Код подтверждения WhatsApp|Code de vérification WhatsApp|WhatsApp验证码
Telefonu doğrula|Verify phone|Telefon bestätigen|Подтвердить телефон|Vérifier le téléphone|验证电话
İletişim bilgisini değiştir|Change contact details|Kontaktdaten ändern|Изменить контактные данные|Modifier les coordonnées|更改联系信息
Bilgi türü|Contact type|Kontaktart|Тип контакта|Type de coordonnées|信息类型
Telefon / WhatsApp|Phone / WhatsApp|Telefon / WhatsApp|Телефон / WhatsApp|Téléphone / WhatsApp|电话 / WhatsApp
Yeni e-posta veya telefon|New email or phone|Neue E-Mail oder Telefonnummer|Новая почта или телефон|Nouvel e-mail ou téléphone|新邮箱或电话
Değişiklik için kod iste|Request change code|Änderungscode anfordern|Запросить код изменения|Demander un code de modification|获取更改验证码
Değiştirilen bilgi|Contact being changed|Zu ändernder Kontakt|Изменяемый контакт|Coordonnée à modifier|要更改的信息
Yeni adrese gelen kod|Code sent to new contact|Code an neuen Kontakt|Код для нового контакта|Code reçu au nouveau contact|新联系方式收到的验证码
Değişikliği doğrula|Confirm change|Änderung bestätigen|Подтвердить изменение|Confirmer la modification|确认更改
Aktif oturumlar|Active sessions|Aktive Sitzungen|Активные сеансы|Sessions actives|活动会话
Bu oturum|This session|Diese Sitzung|Этот сеанс|Cette session|当前会话
Oturumu kapat|End session|Sitzung beenden|Завершить сеанс|Fermer la session|结束会话
Aktif oturum bulunmuyor.|No active sessions.|Keine aktiven Sitzungen.|Нет активных сеансов.|Aucune session active.|没有活动会话。
WhatsApp bağlantısı henüz yapılandırılmamış.|WhatsApp connection is not configured yet.|WhatsApp-Verbindung noch nicht eingerichtet.|WhatsApp ещё не настроен.|WhatsApp n’est pas encore configuré.|WhatsApp连接尚未配置。
Mevcut parolanızı kontrol edin.|Check your current password.|Prüfen Sie Ihr aktuelles Passwort.|Проверьте текущий пароль.|Vérifiez votre mot de passe actuel.|请检查当前密码。
Bir dakika sonra yeniden deneyin.|Try again in one minute.|In einer Minute erneut versuchen.|Повторите через минуту.|Réessayez dans une minute.|请一分钟后重试。
Kod hatalı veya süresi dolmuş.|Code incorrect or expired.|Code falsch oder abgelaufen.|Код неверен или истёк.|Code incorrect ou expiré.|验证码错误或过期。
Bu iletişim bilgisi kullanılamıyor.|This contact is unavailable.|Dieser Kontakt ist nicht verfügbar.|Этот контакт недоступен.|Cette coordonnée est indisponible.|此联系方式不可用。
Doğrulama tamamlandı.|Verification completed.|Bestätigung abgeschlossen.|Подтверждение завершено.|Vérification terminée.|验证完成。
Kod gönderim kuyruğuna alındı. Kod 10 dakika geçerlidir.|Code queued. It is valid for 10 minutes.|Code vorgemerkt. Er gilt 10 Minuten.|Код в очереди. Он действителен 10 минут.|Code en attente d’envoi. Valide 10 minutes.|验证码已进入发送队列，有效期10分钟。
Diğer oturumlar kapatıldı. Bu oturumunuz açık.|Other sessions closed. This session remains active.|Andere Sitzungen geschlossen. Diese bleibt aktiv.|Другие сеансы закрыты. Этот остаётся активным.|Les autres sessions sont fermées. Celle-ci reste active.|其他会话已关闭，当前会话保留。
Oturumlar kapatılamadı.|Unable to close sessions.|Sitzungen konnten nicht beendet werden.|Не удалось завершить сеансы.|Impossible de fermer les sessions.|无法关闭会话。
Oturum kapatılamadı.|Unable to close session.|Sitzung konnte nicht beendet werden.|Не удалось завершить сеанс.|Impossible de fermer la session.|无法关闭会话。
Kimlik numarası ve doğum tarihini kontrol edin.|Check identity number and date of birth.|Prüfen Sie Identitätsnummer und Geburtsdatum.|Проверьте номер документа и дату рождения.|Vérifiez le numéro d’identité et la date de naissance.|请检查身份证号和出生日期。
Başvurunuz yönetici incelemesine gönderildi.|Submitted for administrator review.|Zur Administratorprüfung gesendet.|Отправлено администратору на проверку.|Envoyé à l’administrateur pour examen.|申请已提交管理员审核。
Bilgiler alınamadı. Lütfen tekrar deneyin.|Unable to load details. Try again.|Daten konnten nicht geladen werden. Versuchen Sie es erneut.|Не удалось загрузить данные. Повторите попытку.|Impossible de charger les données. Réessayez.|无法加载资料，请重试。
E-posta veya parola hatalı.|Incorrect email or password.|E-Mail oder Passwort falsch.|Неверная почта или пароль.|E-mail ou mot de passe incorrect.|邮箱或密码错误。
E-posta veya parola hatalı; çok sayıda denemede hesabınız geçici kilitlenir.|Incorrect email or password. Repeated attempts temporarily lock your account.|E-Mail oder Passwort falsch. Wiederholte Versuche sperren Ihr Konto vorübergehend.|Неверная почта или пароль. Повторные попытки временно блокируют аккаунт.|E-mail ou mot de passe incorrect. Des tentatives répétées bloquent temporairement le compte.|邮箱或密码错误，多次尝试会暂时锁定账户。
Çok fazla deneme. Bir dakika sonra tekrar deneyin.|Too many attempts. Try again in a minute.|Zu viele Versuche. In einer Minute erneut versuchen.|Слишком много попыток. Повторите через минуту.|Trop de tentatives. Réessayez dans une minute.|尝试过多，请一分钟后重试。
İşlem şu anda tamamlanamıyor.|Request temporarily unavailable.|Anfrage derzeit nicht verfügbar.|Запрос временно недоступен.|Demande temporairement indisponible.|操作暂时不可用。

Hesabım|My account|Mein Konto|Мой аккаунт|Mon compte|我的账户
Anasayfa|Home|Startseite|Главная|Accueil|首页
NEXUS Agency · Müşteri hesabı|NEXUS Agency · Customer account|NEXUS Agency · Kundenkonto|NEXUS Agency · Аккаунт клиента|NEXUS Agency · Compte client|NEXUS Agency · 客户账户
Seyahatlerinizi, siparişlerinizi ve kaydettiğiniz yerleri tek yerden yönetin.|Manage trips, orders and saved places in one place.|Reisen, Bestellungen und gespeicherte Orte an einem Ort verwalten.|Управляйте поездками, заказами и сохранёнными местами в одном месте.|Gérez voyages, commandes et lieux favoris au même endroit.|在一处管理旅行、订单和收藏地点。
Yeni bir yolculuk keşfet|Discover a new journey|Neue Reise entdecken|Откройте новую поездку|Découvrez un nouveau voyage|探索新旅程
Yaklaşan seyahat|Upcoming trip|Bevorstehende Reise|Предстоящая поездка|Voyage à venir|即将到来的旅行
Rezervasyon|Booking|Buchung|Бронирование|Réservation|预订
Sipariş|Order|Bestellung|Заказ|Commande|订单
Kaydedilen|Saved|Gespeichert|Сохранено|Enregistrés|已收藏
Hesap bölümleri|Account sections|Kontobereiche|Разделы аккаунта|Rubriques du compte|账户栏目
Genel bakış|Overview|Übersicht|Обзор|Vue d’ensemble|概览
GENEL BAKIŞ|OVERVIEW|ÜBERSICHT|ОБЗОР|VUE D’ENSEMBLE|概览
Seyahatlerim|My trips|Meine Reisen|Мои поездки|Mes voyages|我的旅行
Sipariş ve faturalar|Orders and invoices|Bestellungen und Rechnungen|Заказы и счета|Commandes et factures|订单与发票
Favoriler ve fiyat takibi|Favourites and price tracking|Favoriten und Preisverfolgung|Избранное и цены|Favoris et suivi des prix|收藏与价格跟踪
Size özel öneriler|Personal recommendations|Persönliche Empfehlungen|Рекомендации для вас|Suggestions personnalisées|个性化推荐
Profil ve yolcular|Profile and travellers|Profil und Reisende|Профиль и путешественники|Profil et voyageurs|资料与旅客
Cüzdan ve puanlar|Wallet and points|Guthaben und Punkte|Кошелёк и баллы|Portefeuille et points|钱包与积分
Destek|Support|Hilfe|Поддержка|Assistance|帮助
Bildirimler|Notifications|Mitteilungen|Уведомления|Notifications|通知
Çıkış yap|Sign out|Abmelden|Выйти|Se déconnecter|退出登录
Profil ve güvenlik|Profile and security|Profil und Sicherheit|Профиль и безопасность|Profil et sécurité|资料与安全
Yardım ve iletişim|Help and contact|Hilfe und Kontakt|Помощь и контакты|Aide et contact|帮助与联系
Rezervasyonlar|Bookings|Buchungen|Бронирования|Réservations|预订
Siparişler ve ödemeler|Orders and payments|Bestellungen und Zahlungen|Заказы и платежи|Commandes et paiements|订单与支付
Favoriler|Favourites|Favoriten|Избранное|Favoris|收藏
Yolculuklarınız burada başlar|Your journeys start here|Ihre Reisen beginnen hier|Ваши поездки начинаются здесь|Vos voyages commencent ici|旅程从这里开始
Planlarınız ve hesabınızla ilgili güncel bilgiler.|Updates on your plans and account.|Aktuelle Informationen zu Plänen und Konto.|Актуальная информация о планах и аккаунте.|Informations sur vos projets et votre compte.|行程与账户最新信息。
Yaklaşan seyahatler|Upcoming trips|Bevorstehende Reisen|Предстоящие поездки|Voyages à venir|即将到来的旅行
Tümünü gör|View all|Alle anzeigen|Посмотреть все|Tout voir|查看全部
Henüz yaklaşan seyahat yok|No upcoming trips yet|Noch keine bevorstehenden Reisen|Пока нет предстоящих поездок|Aucun voyage à venir|暂无即将到来的旅行
Yeni bir rezervasyon yaptığınızda seyahat planınız burada görünür.|New bookings will appear here.|Neue Buchungen werden hier angezeigt.|Новые бронирования появятся здесь.|Vos nouvelles réservations apparaîtront ici.|新预订将在此显示。
Seyahatleri keşfet|Explore trips|Reisen entdecken|Найти поездки|Découvrir les voyages|探索旅行
Yolculuğunuzda yanınızdayız|Here to help with your journey|Wir begleiten Ihre Reise|Мы поможем в путешествии|À vos côtés pour votre voyage|为您的旅程提供帮助
Rezervasyon, ödeme veya seyahat planınızla ilgili yardım alın.|Get help with bookings, payments or travel plans.|Hilfe zu Buchungen, Zahlungen oder Reiseplänen.|Помощь с бронированием, оплатой и планами.|Obtenez de l’aide pour vos réservations, paiements ou voyages.|获取预订、支付或行程帮助。
Destek ekibine ulaşın|Contact support|Support kontaktieren|Связаться с поддержкой|Contacter l’assistance|联系支持团队
Hızlı erişim|Quick access|Schnellzugriff|Быстрый доступ|Accès rapide|快速访问
HESAP AYARLARI|ACCOUNT SETTINGS|KONTOEINSTELLUNGEN|НАСТРОЙКИ АККАУНТА|PARAMÈTRES DU COMPTE|账户设置
Hesap bilgileriniz ve güvenliğiniz.|Your account details and security.|Ihre Kontodaten und Sicherheit.|Данные и безопасность аккаунта.|Vos données et la sécurité du compte.|账户资料与安全。
E-posta adresi|Email address|E-Mail-Adresse|Адрес электронной почты|Adresse e-mail|邮箱地址
Henüz eklenmemiş|Not added yet|Noch nicht hinzugefügt|Ещё не добавлено|Pas encore ajouté|尚未添加
Hesap desteği alın|Get account support|Kontohilfe erhalten|Помощь с аккаунтом|Obtenir de l’aide|获取账户帮助
Hesap bilgileriniz oturumunuzla korunur. Bilgilerinizde değişiklik veya şifre yardımı için destek ekibimizle iletişime geçin.|Your account is protected by your session. Use the security section to update contacts or get password help.|Ihr Konto ist geschützt. Nutzen Sie den Sicherheitsbereich für Kontaktänderungen und Passworthilfe.|Аккаунт защищён. Используйте раздел безопасности для изменения контактов и восстановления пароля.|Votre compte est protégé. Utilisez la rubrique sécurité pour modifier vos coordonnées ou votre mot de passe.|账户受会话保护，请使用安全栏目更新联系方式或获取密码帮助。
Cüzdan|Wallet|Guthaben|Кошелёк|Portefeuille|钱包
Cüzdanım|My wallet|Mein Guthaben|Мой кошелёк|Mon portefeuille|我的钱包
Puan ve sadakat|Points and rewards|Punkte und Treueprogramm|Баллы и лояльность|Points et fidélité|积分与会员奖励
Faturalarım|My invoices|Meine Rechnungen|Мои счета|Mes factures|我的发票
BAKİYEM|MY BALANCE|MEIN GUTHABEN|МОЙ БАЛАНС|MON SOLDE|我的余额
AVANTAJLARIM|MY BENEFITS|MEINE VORTEILE|МОИ ПРИВИЛЕГИИ|MES AVANTAGES|我的权益
BELGELERİM|MY DOCUMENTS|MEINE DOKUMENTE|МОИ ДОКУМЕНТЫ|MES DOCUMENTS|我的文档
MEVCUT PUAN|CURRENT POINTS|AKTUELLE PUNKTE|ТЕКУЩИЕ БАЛЛЫ|POINTS ACTUELS|当前积分
Kullanılabilir bakiye|Available balance|Verfügbares Guthaben|Доступный баланс|Solde disponible|可用余额
Tanımlanan bakiyeler ve hesap hareketleri.|Balances and account transactions.|Guthaben und Kontobewegungen.|Баланс и операции по счёту.|Soldes et opérations du compte.|余额与账户交易。
Seyahatlerinizle bağlantılı üyelik bilgileri.|Membership details related to your trips.|Mitgliedschaftsdaten zu Ihren Reisen.|Данные участия, связанные с поездками.|Informations d’adhésion liées à vos voyages.|与旅行相关的会员信息。
Siparişlerinize ait düzenlenmiş belgeler.|Documents issued for your orders.|Ausgestellte Dokumente zu Ihren Bestellungen.|Документы по вашим заказам.|Documents établis pour vos commandes.|订单相关文档。
Henüz cüzdan hareketi yok|No wallet transactions yet|Noch keine Guthabenbewegungen|Операций пока нет|Aucune opération pour le moment|暂无钱包交易
İade ve tanımlanan bakiyeler burada görünecek.|Refunds and credits will appear here.|Erstattungen und Guthaben erscheinen hier.|Возвраты и зачисления появятся здесь.|Remboursements et crédits apparaîtront ici.|退款和入账将在此显示。
Yardım alın|Get help|Hilfe erhalten|Получить помощь|Obtenir de l’aide|获取帮助
Henüz faturanız yok|No invoices yet|Noch keine Rechnungen|Счетов пока нет|Aucune facture pour le moment|暂无发票
Düzenlenen faturalarınız burada listelenecek.|Your invoices will be listed here.|Ihre Rechnungen werden hier aufgeführt.|Ваши счета будут показаны здесь.|Vos factures seront affichées ici.|您的发票将在此列出。
Fatura desteği|Invoice support|Rechnungshilfe|Помощь со счетами|Aide pour les factures|发票支持
Hesap bilgileri açılamadı|Unable to open account details|Kontodaten konnten nicht geöffnet werden|Не удалось открыть данные аккаунта|Impossible d’ouvrir les données du compte|无法打开账户资料
Lütfen sayfayı yenileyin veya destek ekibiyle iletişime geçin.|Refresh the page or contact support.|Seite aktualisieren oder Support kontaktieren.|Обновите страницу или обратитесь в поддержку.|Actualisez la page ou contactez l’assistance.|请刷新页面或联系支持团队。
Destek alın|Get support|Hilfe erhalten|Получить поддержку|Obtenir de l’aide|获取支持
Tarih belirtilmemiş|No date specified|Kein Datum angegeben|Дата не указана|Date non précisée|未指定日期
Talep alındı|Request received|Anfrage erhalten|Запрос получен|Demande reçue|已收到请求
Ön rezervasyon|Provisional booking|Vorläufige Buchung|Предварительное бронирование|Réservation provisoire|临时预订
Onaylandı|Confirmed|Bestätigt|Подтверждено|Confirmé|已确认
İptal edildi|Cancelled|Storniert|Отменено|Annulé|已取消
Tamamlandı|Completed|Abgeschlossen|Завершено|Terminé|已完成
Beklemede|Pending|Ausstehend|Ожидается|En attente|待处理
İade edildi|Refunded|Erstattet|Возвращено|Remboursé|已退款
Ödendi|Paid|Bezahlt|Оплачено|Payé|已支付
Ödeme bekliyor|Awaiting payment|Zahlung ausstehend|Ожидается оплата|Paiement attendu|待支付
Provizyonda|Authorized|Autorisiert|Авторизовано|Autorisé|已授权
Başarısız|Failed|Fehlgeschlagen|Не удалось|Échec|失败
Düzenlendi|Issued|Ausgestellt|Выставлен|Établie|已开具
Taslak|Draft|Entwurf|Черновик|Brouillon|草稿
Hazırlanıyor|Preparing|In Vorbereitung|Готовится|En préparation|准备中
İptal|Cancelled|Storniert|Отменено|Annulé|已取消
İşlemde|Processing|In Bearbeitung|Обрабатывается|En cours|处理中
E-fatura|E-invoice|E-Rechnung|Электронный счёт|Facture électronique|电子发票
E-arşiv fatura|E-archive invoice|E-Archivrechnung|Архивный электронный счёт|Facture e-archive|电子存档发票
Makbuz|Receipt|Beleg|Квитанция|Reçu|收据
misafir|guests|Gäste|гостей|voyageurs|位客人
Misafir|Guest|Gast|Гость|Voyageur|客人

WhatsApp gönderimi başarısız. Bağlantıyı kontrol etmek için acenteyle iletişime geçin.|WhatsApp sending failed. Contact the agency to check the connection.|WhatsApp-Versand fehlgeschlagen. Kontaktieren Sie die Agentur.|Не удалось отправить WhatsApp. Свяжитесь с агентством.|Échec de l’envoi WhatsApp. Contactez l’agence.|WhatsApp发送失败，请联系旅行社检查连接。
WhatsApp gönderimi kabul edildi. Telefonunuzu gelen kodla doğrulayın.|WhatsApp accepted the message. Verify your phone with the code you receive.|WhatsApp hat die Nachricht angenommen. Bestätigen Sie Ihr Telefon mit dem erhaltenen Code.|WhatsApp принял сообщение. Подтвердите телефон полученным кодом.|WhatsApp a accepté le message. Vérifiez votre téléphone avec le code reçu.|WhatsApp已接受消息，请使用收到的验证码验证电话。
Kodun süresi doldu. Yeni kod isteyin.|Code expired. Request a new code.|Code abgelaufen. Fordern Sie einen neuen an.|Код истёк. Запросите новый.|Le code a expiré. Demandez-en un nouveau.|验证码已过期，请获取新验证码。
Ayarlara dön|Back to settings|Zurück zu Einstellungen|Назад к настройкам|Retour aux paramètres|返回设置
İki aşamalı giriş|Two-factor authentication|Zwei-Faktor-Authentifizierung|Двухфакторная аутентификация|Authentification à deux facteurs|双重身份验证
Doğrulama uygulamanıza anahtarı ekleyin, kurtarma kodlarını güvenli bir yerde saklayın ve uygulamanın ürettiği kodla etkinleştirin.|Add the key to your authenticator app, save recovery codes securely and enable with a verification code.|Fügen Sie den Schlüssel Ihrer Authenticator-App hinzu, speichern Sie Wiederherstellungscodes sicher und bestätigen Sie mit einem Code.|Добавьте ключ в приложение, сохраните резервные коды и включите проверку кодом.|Ajoutez la clé à votre application, conservez les codes de secours et activez avec un code.|在验证应用中添加密钥，安全保存恢复码，并使用验证码启用。
Uygulama kodu veya kurtarma kodu|App code or recovery code|App-Code oder Wiederherstellungscode|Код приложения или резервный код|Code de l’application ou de secours|应用验证码或恢复码
Kurulumu başlat|Start setup|Einrichtung starten|Начать настройку|Commencer la configuration|开始设置
Etkinleştir|Enable|Aktivieren|Включить|Activer|启用
Devre dışı bırak|Disable|Deaktivieren|Отключить|Désactiver|禁用
Kurulum hazır. Uygulama koduyla etkinleştirin.|Setup ready. Enable with an app code.|Einrichtung bereit. Mit App-Code aktivieren.|Настройка готова. Включите кодом приложения.|Configuration prête. Activez avec un code.|设置已准备就绪，请使用应用验证码启用。
İki aşamalı giriş etkin. Sonraki girişinizde uygulama kodu veya kurtarma kodu gerekir.|Two-factor authentication enabled. Future sign-ins require an app or recovery code.|Zwei-Faktor-Anmeldung aktiv. Künftige Anmeldungen benötigen einen App- oder Wiederherstellungscode.|Двухфакторная проверка включена. Для входа нужен код приложения или резервный код.|Authentification activée. Les prochaines connexions nécessitent un code.|双重验证已启用，下次登录需应用验证码或恢复码。
İki aşamalı giriş kapatıldı.|Two-factor authentication disabled.|Zwei-Faktor-Anmeldung deaktiviert.|Двухфакторная проверка отключена.|Authentification à deux facteurs désactivée.|双重验证已禁用。
İki aşamalı giriş zaten etkin.|Two-factor authentication is already enabled.|Zwei-Faktor-Anmeldung bereits aktiv.|Двухфакторная проверка уже включена.|Authentification déjà activée.|双重验证已启用。
Parola ve kodu kontrol edin.|Check password and code.|Passwort und Code prüfen.|Проверьте пароль и код.|Vérifiez le mot de passe et le code.|请检查密码和验证码。
Üyelik ve gizlilik|Membership and privacy|Mitgliedschaft und Datenschutz|Условия и конфиденциальность|Adhésion et confidentialité|会员与隐私
Üyelik ekranına dön|Back to registration|Zurück zur Registrierung|Назад к регистрации|Retour à l’inscription|返回注册
`.trim().split('\n').map(line=>line.split('|'));
const dict=new Map(rows.map(r=>[r[0],r])),sources=new WeakMap(),attrs=new WeakMap();
function saveLanguage(code){for(const key of ['agency_lang','nexus_lang'])document.cookie=key+'='+code+'; Path=/; SameSite=Lax; Max-Age=31536000';try{localStorage.setItem('chisfis-lang',code);}catch(_){} }const selected=new URLSearchParams(location.search).get('lang');if(languages.includes(selected))saveLanguage(selected);
const lang=()=>{const query=new URLSearchParams(location.search).get('lang');const cookie=(document.cookie.split('; ').find(x=>x.startsWith('nexus_lang='))||document.cookie.split('; ').find(x=>x.startsWith('agency_lang=')))?.split('=')[1];const candidate=(query||window.NEXUS_LOCALE?.lang||cookie||document.documentElement.lang||'tr').split('-')[0];return languages.includes(candidate)?candidate:'tr';};
function text(value){const i=languages.indexOf(lang()),v=value.trim(),row=dict.get(v);if(row)return value.replace(v,row[i]);const single=v.match(/^(E-posta|Telefon): (Doğrulandı|Doğrulanmadı)$/);if(single)return text(single[1])+': '+text(single[2]);const match=v.match(/^(E-posta|Telefon): (Doğrulandı|Doğrulanmadı) · (Telefon): (Doğrulandı|Doğrulanmadı)$/);if(match)return text(match[1])+': '+text(match[2])+' · '+text(match[3])+': '+text(match[4]);const prefixes=[['Merhaba, ','Hello, ','Hallo, ','Здравствуйте, ','Bonjour, ','您好，'],['Üyelik tarihi: ','Member since: ','Mitglied seit: ','Дата регистрации: ','Membre depuis : ','注册日期：'],['Üyelik seviyesi: ','Membership level: ','Mitgliedschaftsstufe: ','Уровень участия: ','Niveau d’adhésion : ','会员等级：'],['Sipariş ','Order ','Bestellung ','Заказ ','Commande ','订单 '],['Fatura ','Invoice ','Rechnung ','Счёт ','Facture ','发票 '],['Ödeme: ','Payment: ','Zahlung: ','Оплата: ','Paiement : ','支付：']];for(const row of prefixes)if(v.startsWith(row[0]))return value.replace(v,row[i]+v.slice(row[0].length));const guests=v.match(/^(\d+) misafir$/);if(guests)return guests[1]+' '+dict.get('misafir')[i];return value;}
window.NEXUS_MEMBER_I18N={text,lang};
let pending=false;
function apply(){pending=false;document.documentElement.lang=lang();const root=document.getElementById('member-auth')||document.getElementById('account-dashboard')||document.querySelector('.cv-card');if(!root)return;const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let n;while(n=walker.nextNode()){if(n.parentElement.closest('script,style'))continue;const previous=sources.get(n);const original=previous&&n.nodeValue===previous.result?previous.original:n.nodeValue;const result=text(original);sources.set(n,{original,result});if(n.nodeValue!==result)n.nodeValue=result;}root.querySelectorAll('[aria-label],[placeholder]').forEach(el=>['aria-label','placeholder'].forEach(a=>{if(!el.hasAttribute(a))return;let saved=attrs.get(el)||{};const now=el.getAttribute(a),old=saved[a],source=old&&now===old.result?old.original:now,result=text(source);saved[a]={original:source,result};attrs.set(el,saved);if(now!==result)el.setAttribute(a,result);}));const heading=root.querySelector('h1,h2');if(heading&&!document.getElementById('account-dashboard'))document.title=heading.textContent+' | NEXUS Agency';}
function schedule(){if(!pending){pending=true;requestAnimationFrame(apply);}}
new MutationObserver(schedule).observe(document.body,{childList:true,subtree:true,characterData:true});document.addEventListener('nexus:lang',e=>{if(languages.includes(e.detail?.lang)){const u=new URL(location.href);u.searchParams.set('lang',e.detail.lang);history.replaceState(null,'',u);}schedule();});
if(document.getElementById('member-auth')){const select=document.createElement('select');select.className='member-language';select.setAttribute('aria-label','Language');select.innerHTML=languages.map((l,i)=>`<option value="${l}">${['Türkçe','English','Deutsch','Русский','Français','中文'][i]}</option>`).join('');select.value=lang();document.body.prepend(select);select.addEventListener('change',()=>{const u=new URL(location.href);u.searchParams.set('lang',select.value);history.replaceState(null,'',u);saveLanguage(select.value);document.documentElement.lang=select.value;document.dispatchEvent(new CustomEvent('nexus:lang'));});}
schedule();})();
