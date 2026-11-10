# Shutdown Timer

**Mac'ini belirlediğin süre sonunda zorla kapat. Hiçbir uygulama engelleyemez.**

Geri sayım bitince Mac'ini kapatan bir Raycast eklentisi (ve tek başına çalışan bir shell scripti). Uygulamalardan izin istemez; bu yüzden "kaydedilmemiş değişiklikler" penceresi ya da takılmış bir uygulama bilgisayarı açık tutamaz.

[English](README.md) | **Türkçe**

---

## Sorun

macOS'un kendi zamanlanmış kapatma yolları kibardır. Açık her uygulamadan kapanmasını rica eder; kaydedilmemiş belgesi ya da onay penceresi olan tek bir uygulama bütün işlemi iptal eder. Saatler sonra döndüğünde Mac hâlâ açıktır.

Shutdown Timer kibar değildir. Süre dolunca root olarak `shutdown -h now` çalıştırır. Uygulamalara sorulmaz, sonlandırılırlar. Bilgisayar 60 saniye sonra hâlâ açıksa `halt -q` ile anında kesilir.

> **Kaydedilmemiş işler kaybolur.** Aracın amacı zaten bu. Kapanmadan 5 dakika ve 1 dakika önce bir uyarı penceresi çıkar, ama hiçbir şey senin yanıt vermeni beklemez.

## Kurulum

macOS, [Raycast](https://www.raycast.com) ve Node.js gerekir.

```bash
git clone https://github.com/merttopuz/shutdown-timer.git
cd shutdown-timer
npm install
npm run dev
```

`npm run dev` eklentiyi Raycast'e kaydeder. Sonrasında durdurabilirsin (`Ctrl+C`); eklenti kurulu kalır.

## Komutlar

| Komut          | Ne yapar                                                                              |
| -------------- | ------------------------------------------------------------------------------------- |
| Start Timer    | Verilen dakika sonunda kapanmayı kurar (boş bırakılırsa 120). Yönetici şifresi ister. |
| Time Remaining | Kapanma saatini ve kalan süreyi gösterir.                                             |
| Cancel Timer   | Aktif zamanlayıcıyı kaldırır. Yönetici şifresi ister.                                 |

Yeni bir zamanlayıcı kurmak, aktif olanın yerine geçer.

## Raycast olmadan

Eklenti tek bir shell scriptinin ince bir sarmalayıcısıdır; script tek başına da çalışır:

```bash
assets/shutdown-timer.sh 90       # 90 dakika sonra kapat (sudo ister)
assets/shutdown-timer.sh status   # kalan süre
assets/shutdown-timer.sh cancel   # zamanlayıcıyı iptal et (sudo ister)
```

## Nasıl çalışır

- **Geri sayımı root olarak çalışan bir LaunchDaemon tutar.** Raycast'i kapatmak, terminali kapatmak, oturumu kapatmak ya da yeniden başlatmak onu durdurmaz. Tek çıkış iptal komutudur.
- **Kullanıcı seviyesindeki hiçbir şey araya giremez.** Scriptin çalışan kopyası root'a ait bir dizine (`/Library/PrivilegedHelperTools`) kurulur; senin adına çalışan bir uygulama onu değiştiremez ya da sonlandıramaz. Süreç yine de öldürülürse launchd yeniden başlatır.
- **Uyku sayacına değil duvar saatine bakar.** Uykuda geçen süre de sayılır. Geri sayım boyunca boşta uykuya geçiş engellenir ve hedef saat için bir uyandırma planlanır. Kapak kapalıysa ve Mac hedef saati uykuda geçirirse, uyanır uyanmaz kapanır.
- **Açılışta sürpriz kapanma olmaz.** Mac hedef saatten önce zaten kapatıldıysa ve sonrasında açıldıysa, eskimiş zamanlayıcı tetiklenmek yerine kendini siler.

## Sisteme ne kurar

Yalnızca bir zamanlayıcı aktifken:

```
/Library/LaunchDaemons/local.shutdown-timer.plist
/Library/PrivilegedHelperTools/local.shutdown-timer.sh
```

İkisi de zamanlayıcı tetiklendiğinde ya da iptal edildiğinde silinir. Sistemde başka bir şey kalmaz.

## Lisans

[MIT](LICENSE)
