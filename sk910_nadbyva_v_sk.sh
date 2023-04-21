#!/bin/bash
#skript srovna data ze Souborneho katalgu CR s vlastnimi daty a ve vystupu vytvori soubor s poli 910, ktere jiz neplati (lokalni zaznamy byly ostraneny) a lye je yaslat Narodni knihovne k odstraneni ze Souborneho katalogu.
#Skript vyzaduje export lokalnich poli ze Souborneho katalogu stazitelny na https://aleph.nkp.cz/skc/download/skc_910_{{sigla}}.tar.gz a z toho zipu nasledne ziskany soubor skc_910_{{sigla}}.dat
#		a dale kompletni export lokalnich dat v Aleph sekvencnim formatu (ziskany pomoci print-03)
#made by Matyas Bajger, osu.cz, 2023, license frei





#cesta ke kompletnimu  sekvencenimu exportu cele BIB baze
sk910file_default='skc_910_SIGLA.dat'
read -p "Soubor s poli 910 ze SK : " -i "$sk910file_default" -e sk910file
if [ ! -f "$sk910file" ]; then echo "ERROR - file $sk910file not found"; exit; fi

#sekvenceni export dat z Alephu
if [ -z ${data_scratch+x} ]; then ds=''; else ds="$data_scratch/"; fi
aleph_seq_def="$ds"'....seq'
echo "Zadejte: a] bud soubor s daty dle aktualni definice pro SK, nebo"
read -p "         b] kompletni export bibl. baze; v seq formatu : " -i "$aleph_seq_def" -e aleph_seq
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
output_file_def='nadbyva_v_sk'
read -p "Vystupni soubor : " -i "$output_file_def" -e output_file
cp /dev/null $output_file

#log
log_file_def="$alephe_dev/alephe/scratch/nadbyva_v_sk.log"
read -p "Log soubor : " -i "$log_file_def" -e log_file
cp /dev/null $log_file



echo START `date` >>$log_file
#extract sysnos from aleph seq file
echo "Extracting sysnos of visible and non-deleted recs from $aleph_seq" | tee -a $log_file
del_field_pat=$(echo "$del_field" | sed 's/\s\+$//' | sed "s/\s\+/' -e '^......... /g" | sed "s/^\s*/-e '^......... /" | sed 's/$/'"'"'/')
grep -v "$del_field_pat" "$aleph_seq" | grep '^......... 001' | sort -u >/tmp/bib_seq.idns


#loop over input file
echo "Loop over SK exports with 910 fields - $sk910file" | tee -a $log_file
linetotal=$(wc -l <"$sk910file")
linecurrent=1;
cp /dev/null /tmp/sk910_navic_v_sk.tmp_sk
cp /dev/null /tmp/sk910_navic_v_sk.tmp_local
#extrakce idno ze sk do tmp souboru
while read line; do
   if [[ $((linecurrent % 1000)) -eq 0 ]]; then
      echo "line $linecurrent (of $linetotal) - "$(( (linecurrent*100) / linetotal ))'%'
   elif [[ $linecurrent -eq 1 ]]; then 
      echo "line 1 (of $linetotal) - 0%"
   fi 
   #check field 910
   is910=$(echo "$line" | grep -c '^......... 910' | bc) 
   if [[ $is910 -lt 1 ]]; then echo "ERROR - line DOES NOT contain field 910: $line" | tee -a $log_file; break; fi
   #count x field(s) occuration
   no_of_x=$(echo "$line" | grep -o '\$\$x' | wc -l | bc )
   if [[ $no_of_x -gt 1 ]]; then
      echo "WARNING - line contains more than one subfiled x, cannot be processed here : $line" | tee -a $log_file
   elif [[ $no_of_x -eq 0 ]]; then
      echo "WARNING - line contains NO subfiled x, cannot be processed here : $line" | tee -a $log_file
   else   #ok, one hint of x subfield
      idno=$(echo "'$line'" | grep -o '\$\$x[^\$]\+' | sed 's/\$\$x//g' | sed "s/'//g")
      if [ $match_id = 'sysno' ]; then
         x=$(grep "^$idno" /tmp/bib_seq.idns | awk '{print $1;}' | sort -u )
      else #idno
         x=$(grep "\s$idno"'$' /tmp/bib_seq.idns | sed 's/^......... 001   L //' | sort -u )
      fi
      xc=$(echo $x | wc -w  | bc)
      if [[ $xc -eq 0 ]]; then
         echo "NOTE $match_id $idno not found in local catalogue. This line can be deleted: $line" | tee -a $log_file
         echo "$idno" >>$output_file
      fi
   fi
   linecurrent=$((++linecurrent))
done <"$sk910file"

dupl_count=$(wc -l <$output_file | bc)
echo | tee -a $log_file
echo END `date` >>$log_file
echo "Log file is : $log_file"
if [[ $dupl_count -eq 0 ]]; then
   echo "Alles gut, kein problem! Nalezeno 0 (slovy nula) nadbyvajicich zaznamu v SK" | tee -a $log_file
else
   echo "Nalezeno $dupl_count zaznamu nadbyvajicich v SK. Seznam techto SK poli 910 k odstraneni v souboru $output_file" | tee -a $log_file
   ls -la "$output_file" | tee -a $log_file
   echo '-------------------'
   head "$output_file" -n5
   echo '(...)'
fi

rm -f /tmp/sk910*



