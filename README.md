# SÉRIE SKRIPTŮ K POROVÁNÍ ID VE VLASTNÍM KATALOGU SE SOUBORNÝM KATALOGEM ČR

Porovnání ID záznamů (sysno) ve vlastním katalogu s daty v Souborném katalogu ČR (dále SK)

Jazyk: Bourne Shell (BASH), jinak vyžaduje jen exporty lokální dat a ze Souborného katalogu.

License: GNU, matyas.bajger@osu.cz


Viz též popisná prezentace https://github.com/osulib/Souborny-katalog---porovnani-ID/blob/main/%C4%8Cist%C3%ADc%C3%AD%20(a%20p%C5%99%C3%ADpravn%C3%A9)%20tipy%20k%20Souborn%C3%A9mu%20katalogu%20(Bajger%2C%20Z%C3%A1ho%C5%99%C3%ADk).pptx


## Vstupy

1. Export pole 910 s vlastní siglou

aktuální exporty pole 910, 1x týdně, v ždy v pondělí, aktualizované:

https://aleph.nkp.cz/skc/download/skc_910_ 910_{{ sigla}}.tar.gz např. https://aleph.nkp.cz/skc/download/skc_910_ola001.tar.gz

Gzip obsahuje:

`skc_910_{{sigla}}.dat` - seznam všech polí 910 $x včetně případů, kdy je v poli 910 několik výskytů podpole $x. Např. `000388082 910 L $$aOSD001$$x000044916$$x000044239`

`skc_910_osd001_err.dat` - částečný export záznamů, kde v poli 910 chybí $x. Záznamy se nedají spárovat s lokálním katalogem a ani použít jako

základ pro centrální katal.

`skc_910_osd001_bk_dup.dat` - seznam duplicitních výskytů 910 $a…$x… v záznamech monografii

`skc_910_osd001_se_dup.dat` - seznam duplicitních výskytů 910 $a…$x… v záznamech seriálů. Případy, kdy v lokálním katalogu mate jeden záznam seriálu, ale v SKC je titul rozdělen do několika záznamů.



## Kontroly

### A. skc_910_{{sigla}}.dat

Ve vstupních parametrech skriptů lze zadat podle čeho je Souborný katalog linkován (IdNumber - Marc 001 // sysno), pole označující skryté záznamy a další.

### A.1 nadbývá v SK - není v lokálním katalogu 

Skript `sk910_nadbyva_v_sk.sh`

Dva možné přístupy:

a) Standardní: srovnání dle aktuální definice dat (báze) pro SK (dle tab_base.* nebo CCL v exportním skriptu). na vstupu export BIB dat dle této definice, vhodný pro „pořádek“

b) Maximalistický: pro navázání co největšího počtu záznamů. na vstupu export celé BIB báze, vhodný jako příprava pro Centrální katalog PNG

Skript ### sk910_nadbyva_v_sk.sh

Na výstupu seznam lokálních ID k odstranění.

`000075479`

`000135487`

Co s tím?

1. Ověřit, jestli v podpoli x není jiný údaj signatura, ISBN apod.

2. Ověřit lokální záznamy ?

3. Poslat R. Záhoříkovi výstup k odstranění ze SK. Pro více sigel každou zvlášť nebo i se siglo. Tento postup je vhodnější než $$pODPIS Podle definice standardního (definice dat pro SK) nebo maximalistického přístupu (celá BIB báze mimo unikátní?)





### A.2 nadbývá v SK - není v lokálním katalogu 

Skript `sk910_chybi_v_sk.sh`

Nepoužívá kompletní SEQ export BIB báze, ale jen záznamy vhodné pro SK (V Aleph dle ccl dotazu v tab_base.eng pro OAI, nebo skriptu pro nahrání u FTP uploadu ). Případně vyloučení jedinečných záznamů (historický fond, přívazky, VŠKP atd.). Například: (`wfm =BK or wfm =MP or wfm =VM or wfm =AM or wfm =DS or wfm =MU ) not wst ztrac * or wst vy * or wst akv * or wst nez *) not wbs ebooks not wbs Proquest Academic Complete"`

Dohledat pomocí ret-01 a export print-03

Umožňuje definovat pole povinná pro fyzický popis: mimo obligátně povinná (001,245 atd …) a vyskytující se ve všech záznamech jde asi jen o fyzický popis 300, případně 910.

Výstupem je seznam sysen se jménem báze (000005644OSU01,...), který lze vyexportovat dále.

Výsledek lze:

a) Vyexportovat do řádkového Marc , upravit dle běžného nastavení a p oslat standardní metodou do SK upload na FTP, zařazení do OAI setu pro sklizeň

! Při poslání více než 10 tisíc záznamů kontaktujte nejprve R. Záhoříka

! Záznamy vzniklé bez knihy v ruce nutno poslat s nižší vahou, jen via FTP - jméno souboru končí _r{{váha}} např. osd001 uc.mal_ 20230411 _r7

Následující den kontrola importu na http://aleph.nkp.cz/web/skc/{{sigla}}/{{sigla}}d.htm

b) Vytvořit řádková pole 910 dle struktury SK, např.

`000388082 910 L $$aOS A 01 x000044916`

A poslat R. Záhoříkovi pro přímý upload do SK bez kontrol. Spáruje se s existujícími záznamy, které musí existovat. Knihovna dostane zpět nespárované případy.





### A.3 pole 910 duplicitní podpole x v SK 

V SK je v poli 910 více než jedno podpole x lokální ID. Vazba vede na více lokálních záznamů.

Skript `sk910_duplicitni_podpole_x.sh`

Automaticky dohledá případy, kdy je lokálně již jen jedno IDno sysno .

Ostatní označí k ruční opravě.

Tři výstupní soubory:

1. `duplicate_sk` = jen jeden záznam v lokálním katalogu, soubor obsahuje lokální ID k odstranění ze SK. Soubor lze poslat do NK.

000116461

000200583

2. `duplicate_sk.multi` = jednomu záznamu v SK odpovídá vice v lokálních datech --> ruční kontrola;

000186684 910 L $$aOSD001$$x000051833$$x000051876

3. `duplicate_sk.nomatch` = ani jeden záznam Idno sysno ) nenalezen(y) v lokálním katalogu --> ruční kontrola, případné odmazání v SK záznamy již mohly být odstraněny pomocí A.1 



### B. Částečný export záznamů, kde v poli 910 chybí $x. 

Soubor exportu `skc_910_{{sigla}}_err.dat `

Např.

`003277956 FMT L SE`

`003277956 022 L $$a0016 741X`

`003277956 24504 L $$ aThe geographical magazine`

`003277956 24631 L $$ aGeographical`

`003277956 260 L $$ aLondon bChampion Interactive Publishing ,$$c[`

`003277956 300 L $$a^^^sv.`

`003277956 910 L $$aOSD001$$ qv $$r1969,70 71`

`006588858 FMT L BK`

`006588858 1001 L $$ aPopiołek , Franciszek,$$d1868 1960$xx0023674$aut`

`006588858 24510 L $$ aDzieje Cieszyna :$$bz illustracyami cFranciszek Popiołek`

`006588858 260 L $$ aCieszyn bWydawnictwo Pol. towarz . pedagogicznego ,$$c1916$$ Drukarnia Tow . domu`

`arod . Pawła Mitręgi`

`006588858 300 L $$a270 s. :$$bil. ;$$c20 cm`

`006588858 910 L $$aOSD001$$bVM1053`

Jde často o záznamy vkládané ručeně pčes Web OPAC SK

Skript: `sk910_chybi_podpole_x.sh`

Dohledá idno/sysno v lokálních datech na základě signatury dle pole 910 nebo Z30 (zde nutný SEQ export s expanzí expand_doc_bib_z30)

Výsledek - pole 910 s doplnenym sysno vhodne pro predani NK pro upload do SK je : chybi_podpole_x

       Chybove a problematicke pripady k rucnimu provereni najdete: chybi_podpole_x.err
Pro opravu SK lze tyto záznamz znova standardní cestou (OAI, FTP) poslat do SK. Lze též zaslat e-mailem samotný výstup skriptu - pole 910 z SK rpo import bez kontrol. Knihovna si však odpovídá za obsah těchto polí.




### Seznam duplicitních výskytů 910 $$x v záznamech 1. monografií a 2. seriálů

soubory 1. skc_910_ 910_{{sigla}}_bk_dup.dat   ##monografie

           2. skc_910_ 910_{{sigla}}_se_dup.dat  ##serisaly

Obsah soborů, např.:

$$aOSD001$$x000054970

$$aOSD001$$x000131419

$$aOSD001$$x000131563

Skript `sk910_duplicitni_hodnota_x.sh`

Výsledek - soubor s instrukcemi k ruční opravě


