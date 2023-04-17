#!/bin/bash
#skript srovna data ze Souborneho katalgu CR - pole 910 s vlastni siglou a soubor s dupllicitnimpouzitim idno{sysno v SK.
#Vystupni soubor obsahuje doporuceni k rucni oprave, ypravidla link na hodledani v SK.
#Skript vyzaduje export lokalnich poli ze Souborneho katalogu stazitelny na https://aleph.nkp.cz/skc/download/skc_910_{{sigla}}.tar.gz a z toho zipu nasledne ziskany soubor skc_910_{{sigla}}.dat
#               a dale kompletni export lokalnich dat v Aleph sekvencnim formatu (ziskany pomoci print-03)
#made by Matyas Bajger, osu.cz, 2023, license frei


#cesta ke kompletnimu exportu pole 910 ze SK
sk910file_default='skc_910_SIGLA.dat'
read -p "Soubor s poli 910 ze SK : " -i "$sk910file_default" -e sk910file
if [ ! -f "$sk910file" ]; then echo "ERROR - file $sk910file not found"; exit; fi

#cesta ke isouboru duplicit z sk ze SK
sk910dupfile_default='skc_910_SIGLA_bk_dup.dat'
read -p "Soubor s poli duplicit podpole 910 ze SK : " -i "$sk910dupfile_default" -e sk910dupfile
if [ ! -f "$sk910dupfile" ]; then echo "ERROR - file $sk910dupfile not found"; exit; fi

#sekvenceni export dat z Alephu
if [ -z ${data_scratch+x} ]; then ds=''; else ds="$data_scratch/"; fi
aleph_seq_def="$ds"'....seq'
read -p "Kompletni export bib baze Alephu v seq formatu : " -i "$aleph_seq_def" -e aleph_seq
if [ ! -f "$aleph_seq" ]; then echo "ERROR - file $aleph_seq not found"; exit; fi

#pole oznacujici smazany/neviditelny zaznam
del_field_def="DEL STA"
read -p "Pole zazanamu oznacujici smazany nebo neviditelny zaznam (oddelena mezerou) : " -i "$del_field_def" -e del_field
del_field=$(echo "$del_field" | sed 's/[,;]/ /g' | sed 's/\s\+/ /g')


#prepinac idno sysno
match_id_def="1"
read -p "Podle ceho je linkovan SK (1 - IDno (pole 001), 2 - sysno) : " -i "$match_id_def" -e match_id
if [ "$match_id" = "1" ]; then match_id='idno'
elif [ "$match_id" = "2" ]; then match_id='sysno'
else  echo "ERROR - unrecognised value: $match_id (should be 1 or 2)"; exit; fi

#output file
output_file_def='duplictni_hodnota_x_sk'
read -p "Vystupn soubor : " -i "$output_file_def" -e output_file
cp /dev/null $output_file

#log
log_file_def="$alephe_dev/alephe/scratch/duplicitni_hodnota_x.log"
read -p "Log soubor : " -i "$log_file_def" -e log_file
cp /dev/null $log_file



echo START `date` >>$log_file
#extract sysnos from aleph seq file
echo "Extracting sysnos of visible and non-deleted recs from $aleph_seq" | tee -a $log_file
del_field_pat=$(echo "$del_field" | sed 's/\s\+$//' | sed "s/\s\+/' -e '^......... /g" | sed "s/^\s*/-e '^......... /" | sed 's/$/'"'"'/')
grep -v "$del_field_pat" "$aleph_seq" | grep '^......... 001' | sort -u >/tmp/bib_seq.idns


#loop over input file
echo "Loop over SK exports with duplicate x values in 910 fields - $sk910dupfile" | tee -a $log_file
linetotal=$(wc -l <"$sk910dupfile")
linecurrent=1;
#extrakce idno ze sk do tmp souboru
while read line; do
   if [[ $((linecurrent % 100)) -eq 0 ]]; then
      echo "line $linecurrent (of $linetotal) - "$(( (linecurrent*100) / linetotal ))'%'
   elif [[ $linecurrent -eq 1 ]]; then 
      echo "line 1 (of $linetotal) - 0%"
   fi 
   #get idno / sysno from 910
   idno=$(echo "$line" | grep -o '\$\$x[0-9]\+' | sed 's/\$\$x//')
   #check idno in local data
   if [ $match_id = 'sysno' ]; then
      found_loc=$(grep "^$idno" /tmp/bib_seq.idns -c | bc )
   else #idno
      found_loc=$(grep "\s$idno"'\s*$' /tmp/bib_seq.idns -c | bc )
   fi
   if [[ $found_loc -eq 0 ]]; then #not found in local data
      echo "$idno - $match_id nebylo nalezeno v lokalnich datech, asi bylo odstraneno?" | tee -a "$log_file" -a "$output_file"
      continue
   fi
   #get SK sysnos
   sk_sysnos=$(grep '$$x'"$idno" "$sk910file" | awk '{print $1;}')
   sk_sysnos_count=$(echo "$sk_sysnos" | wc -l | bc)
   if [[ $sk_sysnos_count -eq 0 ]]; then 
      echo "$idno - error: $match_id nebylo nalezeno v 910 exportu SK $sk910file  Dohledejte rucne (web SK)" | tee -a "$log_file" -a "$output_file"
   elif [[ $sk_sysnos_count -eq 1 ]]; then 
      echo "$idno - note: $match_id sice ma byt duplicitni, ale v 910 exportu SK $sk910file se naslo jen 1x. Overte: " | tee -a "$log_file" -a "$output_file"
      echo "		 https://aleph.nkp.cz/F/?func=direct&doc_number=$sk_sysnos&local_base=SKC" | tee -a "$output_file"
   else
      echo "$idno - $match_id nalezeno ve vice zaznamech ($sk_sysnos_count) v SK. Overte: " >> "$output_file"
      ccl=$(echo "$sk_sysnos" | tr -s '\n' ' ' | sed 's/\s*$//' | sed 's/ /+or+sys%3D/g' | sed 's/^\s*/sys%3D/')
      echo "		https://aleph.nkp.cz/F/SESSION?func=find-c&local_base=SKC&ccl_term=$ccl" >>  "$output_file"
    fi
   linecurrent=$((++linecurrent))
done <"$sk910dupfile"        


echo END `date` >>$log_file
echo "Log file is : $log_file"
echo "Result file is : $output_file" | tee -a "$log_file"
echo "    (v URL aleph.nkp.cz vystupniho souboru nahradte SESSION skutecnou session zalozeno v Alephu NK)" | tee -a "$log_file"


