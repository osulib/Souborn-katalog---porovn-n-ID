#!/bin/bash
#skript srovna data ze Souborneho katalgu CR - pole 910 s vlastni siglou, ktera obsahuji vice nez jedno podpole x s ID number nebo sysnem lokalniho zaznamu. Vystupni soubor TODO co obsahuj
#Skript vyzaduje export lokalnich poli ze Souborneho katalogu stazitelny na https://aleph.nkp.cz/skc/download/skc_910_{{sigla}}.tar.gz a z toho zipu nasledne ziskany soubor skc_910_{{sigla}}.dat
#               a dale kompletni export lokalnich dat v Aleph sekvencnim formatu (ziskany pomoci print-03)
#made by Matyas Bajger, osu.cz, 2023, license frei


#cesta ke exportu pole 910 ze SK
sk910file_default='skc_910_SIGLA.dat'
read -p "Soubor s poli 910 ze SK : " -i "$sk910file_default" -e sk910file
if [ ! -f "$sk910file" ]; then echo "ERROR - file $sk910file not found"; exit; fi

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

#Rsigla
sigla_def=''
read -p "Vase sigla : " -i "$sigla_def" -e sigla
sigla=$(echo "$sigla" | sed 's/\s//g' | tr a-z A-Z)

#output file
output_file_def='duplicate_sk'
read -p "Vystupni soubory : " -i "$output_file_def" -e output_file
cp /dev/null $output_file
cp /dev/null $output_file.multi
cp /dev/null $output_file.nomatch

#log
log_file_def="$alephe_dev/alephe/scratch/duplicitni_podpole_x.log"
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
      ids='' 
      err=0
      sk_sysno=$(echo "$line" | awk '{print $1;}')
      echo "'$line'" | grep -o '\$\$x[^\$]\+' | sed 's/\$\$x//g' | sed "s/'//g" | while read idno; do
         if [ $match_id = 'sysno' ]; then
            x=$(grep "^$idno" /tmp/bib_seq.idns | awk '{print $1;}' | sort -u )
         else #idno
            x=$(grep "\s$idno"'$' /tmp/bib_seq.idns | sed 's/^......... 001   L //' | sort -u )
         fi
         xc=$(echo $x | wc -w  | bc)
         if [[ $xc -gt 1 ]]; then
            echo "	ERROR - more than one records ($xc) with $idno found in aleph seq export. Process manually"
            err=$((++err))
         elif [[ $xc -eq 1 ]]; then   
            ids="$ids $x"
         fi
         echo "$ids" >/tmp/ids
      done
      ids=$(cat /tmp/ids)
      if [[ $err -lt 1 ]]; then 
         idcount=$(echo "$ids" | wc -w | bc)
         if [ "$idcount" = 1 ]; then  #array length, great just one hint, construct the line to output file
            ids=$(echo "$ids" | sed 's/\s//g')
            echo "	one hint - result is: $sk_sysno 910   L "'$$a'"$sigla"'$$x'"$ids" | tee -a "$log_file"
            echo "$sk_sysno 910   L "'$$a'"$sigla"'$$x'"$ids" >>"$output_file"
         elif [ "$idcount" = 0 ]; then #no hints, no idn found
            echo "	WARNING - no $match_id has been found in aleph seq data for this line ( $line ) " | tee -a "$log_file"
            echo "$line" >>"$output_file.nomatch"
         else #more than one found
            echo "      WARNING - $match_id has been found $idcount times (multiple) in aleph seq data for this line ( $line ) " | tee -a "$log_file"
            echo "$line" >>"$output_file.multi"
         fi
      fi
   fi
   linecurrent=$((++linecurrent))
done <"$sk910file"        


echo END `date` >>$log_file
echo "Log file is : $log_file"
echo "Result files are : " | tee -a "$log_file"
ls -la "$output_file"* | tee -a "$log_file"
printf "\n(1. $output_file = jen jeden zaznam v lokalnim katalogu, soubor lze poslat do NK na opravu pole 910;\n 2. $output_file"".multi = jednomu zaznamu v SK odpovida vice v lokalnich datech (rucni kontrola);\n3. $output_file"".nomatch = ani jeden zaznam ($match_id) nenalezen(y) v lokalnim katalogu.\n" | tee -a "$log_file"


