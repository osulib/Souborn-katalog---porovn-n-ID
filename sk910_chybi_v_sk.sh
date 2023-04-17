#!/bin/bash
#!/bin/bash
#skript srovna data ze Souborneho katalgu CR s vlastnimi daty a ve vystupu vytvori soubor se sysny zaznamu, ktere v Soubornem katalogu nejsou, ale potencialne by mohly byt. Dle tohoto seynamu sysen lze udelat export se vsemi expanzemi, upravami a kontrolami jako do Souborneho katalogu a data do nej poslat. TODO jak poslat ftp a vaha.
#Poslat soubory lze via ftp, jmeno souboru je {{sigla_lowercase}}uc.mal_{{datum}}
#Pokud katalogizace neprobihala s knihou v ruce, poslete je jako zaznamy s nizsi vahou - jmeno souboru puttnuteho na ftp bude koncit _r{{vaha}}, napr _r7, osd001uc.mal_YYYYMMDD_r7
#
#Skript vyzaduje export lokalnich poli ze Souborneho katalogu stazitelny na https://aleph.nkp.cz/skc/download/skc_910_{{sigla}}.tar.gz a z toho zipu nasledne ziskany soubor skc_910_{{sigla}}.dat
#               a dale kompletni export lokalnich dat v Aleph sekvencnim formatu (ziskany pomoci print-03)
#made by Matyas Bajger, osu.cz, 2023, license frei



#cesta ke kompletnimu  sekvencenimu exportu cele BIB baze
sk910file_default='skc_910_SIGLA.dat'
read -p "Soubor s poli 910 ze SK : " -i "$sk910file_default" -e sk910file
if [ ! -f "$sk910file" ]; then echo "ERROR - file $sk910file not found"; exit; fi

#sekvenceni export dat z Alephu
if [ -z ${data_scratch+x} ]; then ds=''; else ds="$data_scratch/"; fi
aleph_seq_def="$ds"'....seq'
echo "Export zaznamu, ktere lze posilat do souborneho katalogu."
echo "	Pouzijte ret-01 s ccl dotazem dle tab_base.eng s definici OAI setu pro SK nebo definici v exportnim skriptu pripravujicim data pro ftp upload"
echo "  Nasledne data vyexportujte pomoci print-03"
read -p "Export BIB baze Alephu, zaznamu pro SK, v seq formatu : " -i "$aleph_seq_def" -e aleph_seq
if [ ! -f "$aleph_seq" ]; then echo "ERROR - file $aleph_seq not found"; exit; fi

#pole oznacujici smazany/neviditelny zaznam
req_field_def="300"
read -p "Pole zazanamu ktera jsou povinna pro SK (oddelena mezerou) : " -i "$req_field_def" -e req_field
req_field=$(echo "$req_field" | sed 's/[,;]/ /g' | sed 's/\s\+/ /g')

#prepinac idno sysno
match_id_def="1"
read -p "Podle ceho je linkovan SK (1 - IDno (pole 001), 2 - sysno) : " -i "$match_id_def" -e match_id
if [ "$match_id" = "1" ]; then match_id='idno'
elif [ "$match_id" = "2" ]; then match_id='sysno'
else  echo "ERROR - unrecognised value: $match_id (should be 1 or 2)"; exit; fi

#BIB baze
bib_base_def='xxx01'
if [ -z ${active_library+x} ]; then bb=$bib_base_def; else bb="$active_library"; fi
read -p "Jmeno BIB baze : " -i "$bb" -e bib_base
bib_base=$(echo "$bib_base" | sed 's/\s//g' | tr a-z A-Z)

#output file
output_file_def='chybi_v_sk'
read -p "Vystupni soubor : " -i "$output_file_def" -e output_file
cp /dev/null $output_file

#log
log_file_def="$alephe_dev/alephe/scratch/chybi_v_sk.log"
read -p "Log soubor : " -i "$log_file_def" -e log_file
cp /dev/null $log_file



echo START `date` >>$log_file
#extract records from local data that can be sent to SK - contain defined fields
echo "Extracting record with required Marc field(s) ($req_field) from local seq file $aleph_seq" | tee -a $log_file
rm -f /tmp/sk_chybi_local.field_*
for rf in $(echo "$req_field"); do
   echo "		extracting field $rf" | tee -a $log_file
   cp /dev/null /tmp/sk_chybi_local.field_$rf
   grep "^......... $rf" "$aleph_seq" | awk '{print $1;}' | sort -u >/tmp/sk_chybi_local.field_$rf
done
echo "		merging all required fields" | tee -a $log_file
rf_count=$(echo "$req_field" | wc -w | bc)
#merge
sort /tmp/sk_chybi_local.field_* | uniq -c | sort -n | grep "^\s*$rf_count\s" | awk '{print $2;}' >/tmp/sk_chybi_local.sysno
if [ $match_id = 'sysno' ]; then
   mv /tmp/sk_chybi_local.sysno /tmp/sk_chybi_local.idno
else #idno
   echo "		getting record IdNos ..." | tee -a $log_file
   linetotal=$(wc -l </tmp/sk_chybi_local.sysno)
   linecurrent=1;
   cp /dev/null /tmp/sk_chybi_local.idno
   while read line; do
      if [[ $((linecurrent % 100)) -eq 0 ]]; then
         echo "			line $linecurrent (of $linetotal) - "$(( (linecurrent*100) / linetotal ))'%'
      elif [[ $linecurrent -eq 1 ]]; then 
         echo "			line 1 (of $linetotal) - 0%"
      fi 
      grep "^$line 001" /exlibris/aleph/u23_1/osu01/scratch/_osu01._zaloha_print03.20230322 | awk '{print substr($0,19);}' | sed 's/\s//g' >>/tmp/sk_chybi_local.idno
      linecurrent=$((++linecurrent))
   done </tmp/sk_chybi_local.sysno

fi



#loop over input file
echo "Look for records currently found in SK export with 910 fields - $sk910file" | tee -a $log_file
linetotal=$(wc -l </tmp/sk_chybi_local.idno)
linecurrent=1;
cp /dev/null /tmp/sk910_chybi_v_sk.tmp
#extrakce idno ze sk do tmp souboru
while read line; do
   if [[ $((linecurrent % 100)) -eq 0 ]]; then
      echo "	line $linecurrent (of $linetotal) - "$(( (linecurrent*100) / linetotal ))'%'
   elif [[ $linecurrent -eq 1 ]]; then 
      echo "	line 1 (of $linetotal) - 0%"
   fi 
   #look for idnos in skc export
   no_of_x=$(grep '\$\$x'"$line" "$sk910file" -c | bc)
   if [[ $no_of_x -eq 0 ]]; then
      echo "$match_id $line not found in SK, adding to output file" | tee -a $log_file
      echo "$line""$bib_base" >>$output_file
   elif [[ $no_of_x -gt 1 ]]; then
      echo "WARNING - $match_id $line found in more than one records in SK" | tee -a $log_file
   fi
   linecurrent=$((++linecurrent))
done </tmp/sk_chybi_local.idno

missing_count=$(wc -l <$output_file | bc)
echo | tee -a $log_file
echo END `date` >>$log_file
echo "Log file is : $log_file"
if [[ $missing_count -eq 0 ]]; then
   echo "Alles gut, kein problem! Nalezeno 0 (slovy nula) chybejicich zaznamu v SK" | tee -a $log_file
else
   echo "Nalezeno $missing_count zaznamu potencialne chybejicich v SK. Jejich seznam (vhodny jako vstup pro export print-03) je v souboru $output_file" | tee -a $log_file
   ls -la "$output_file" | tee -a $log_file
   echo "Tyto zaznamy muzete vyexportovat, upravit a via ftp poslat do SK"  | tee -a $log_file
   echo 'Poslat soubory lze via ftp, jmeno souboru je {{sigla_lowercase}}uc.mal_{{datum}}' | tee -a $log_file
   echo "Pokud katalogizace neprobihala s knihou v ruce, poslete je jako zaznamy s nizsi vahou - jmeno souboru puttnuteho na ftp bude koncit _r{{vaha}}, napr _r7, osd001uc.mal_YYYYMMDD_r7" | tee -a $log_file
fi

rm -f /tmp/sk910*



