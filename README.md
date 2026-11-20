# BannerCut

Aplicație Flutter pentru planificarea tăierii bannerelor recuperate. Disponibilă ca proiect nativ pentru Android, iOS și Linux.

## Rulează local

Folosește Flutter 3.44.8 sau o versiune compatibilă cu Dart 3.12.2.

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

Pentru Android, conectează un telefon cu depanare USB sau pornește un emulator. Poți genera un APK pentru testare cu `flutter build apk --debug`. Pentru iOS ai nevoie de macOS cu Xcode, iar importul din galerie cere iOS 14 sau mai nou. Pentru aplicația desktop, rulează `flutter run -d linux` pe Linux.

## Fluxul aplicației

1. Deschide exemplul preîncărcat sau alege **Banner nou** din meniu. Introdu lățimea și înălțimea în centimetri.
2. Opțional, importă o fotografie frontală, decupată la marginile bannerului. În **Editează**, desenează dreptunghiuri peste defecte și șterge-le individual dacă e nevoie.
3. Alege **Sacoșă** sau **Husă**, marja pe fiecare latură și numărul maxim de seturi pe care le cauți.
4. În **Manual**, atinge colțul stânga-sus în care vrei să pui următoarea piesă. Poți roti piesa înainte de plasare sau retrage ultima piesă.
5. Apasă **Optimizează planul**. Compară rezultatul cu așezarea de referință fără rotații și cu planul manual, dacă ai așezat cel puțin un set complet. Atinge o piesă pentru a vedea dimensiunile de tăiere și poziția față de colțul stânga-sus al bannerului. Poți copia lista completă de cote din **Listă de tăiere**.

Aplicația procesează local fotografia și geometria. Sesiunea curentă este ținută în memorie. Când schimbi materialul, șablonul, marja sau limita, aplicația recalculează geometria materialului și golește planurile existente. Defectele sunt dreptunghiuri, iar fotografia servește drept reper vizual.

## Optimizare și indicatori

Planificatorul împarte spațiul disponibil în dreptunghiuri libere după fiecare zonă deteriorată sau piesă plasată. Încearcă ordini diferite pentru piese, mai multe criterii de alegere a spațiului și rotații de 90°. Păstrează planul cu cele mai multe seturi complete dintre cele încercate. Metoda este euristică.

Indicatorul din interfață împarte suprafața pieselor din seturile complete, cu marja inclusă, la suprafața utilizabilă a bannerului. Zonele deteriorate care se suprapun sunt scăzute o singură dată. Pentru măsurarea impactului fizic se poate cântări materialul rămas după tăiere pe bannere comparabile, folosind același șablon și aceeași marjă.

## Verificare

```sh
flutter analyze
flutter test
```

Testele acoperă suprapunerea defectelor, rotația pieselor, marginile de cusătură, seturile incomplete și fluxurile de editare și optimizare în interfață.
