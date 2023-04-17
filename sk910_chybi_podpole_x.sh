#!/bin/bash
#!/bin/bash
#skript srovna data ze Souborneho katalgu CR - kde chybi v poli 910 podpole x </ s vlastnimi daty, v nichz se dle signatury pokusi dohledat jedinecne sysno nebo IDno.
#Vystup: doplnena jedinecna idno/sysno do pole 910 podple x (lze poslat do SK], TODO chzbz
#
#Skript vyzaduje export lokalnich poli ze Souborneho katalogu stazitelny na https://aleph.nkp.cz/skc/download/skc_910_{{sigla}}.tar.gz a z toho zipu nasledne ziskany soubor skc_910_{{sigla}}_err.dat
#               a dale kompletni export lokalnich dat v Aleph sekvencnim formatu (ziskany pomoci print-03)
#made by Matyas Bajger, osu.cz, 2023, license frei



#cesta ke kompletnimu  sekvencenimu exportu cele BIB baze
sk910file_default='skc_910_SIGLA_err.dat'
read -p "Soubor _err  ze SK : " -i "$sk910file_default" -e sk910file
if [ ! -f "$sk910file" ]; then echo "ERROR - file $sk910file not found"; exit; fi

#sekvenceni export dat z Alephu
if [ -z ${data_scratch+x} ]; then ds=''; else ds="$data_scratch/"; fi
aleph_seq_def="$ds"'....seq'
read -p "Kompletni export bib baze Alephu v seq formatu : " -i "$aleph_seq_def" -e aleph_seq
if [ ! -f "$aleph_seq" ]; then echo "ERROR - file $aleph_seq not found"; exit; fi

#pole obsahujici signaturu
call_field_def="910"
read -p "Pole lokalniho zazanamu obsahujici signaturu pouzite dale k srovnani (910,Z30): " -i "$call_field_def" -e call_field
call_field=$(echo "$call_field" | sed 's/[,;]/ /g' | sed 's/\s\+/ /g')
if [[ ${#call_field} -lt 3 ]] ; then echo "ERROR - definice pole musi mit alespon tri znaky"; exit
elif [[ ${#call_field} -gt 5 ]] ; then echo "ERROR - definice pole nemuze mit vic nez 5 znaku"; exit 
fi


#PODpole obsahujici signaturu
call_subfield_def=""
if [ "$call_field" = '910' ]; then
   call_subfield_def='b'
elif [ "$call_field" = 'Z30' ]; then
   call_subfield_def='3'
fi
read -p "PODpole lokalniho zazanamu obsahujici signaturu pouzite dale k srovnani (b pro 910, 3 pro Z30): " -i "$call_subfield_def" -e call_subfield
call_subfield=$(echo "$call_subfield" | sed 's/[,;]/ /g' | sed 's/\s\+/ /g')
if [[ ${#call_subfield} -lt 1 ]] ; then echo "ERROR - definice PODpole nemuze byt prazdna"; exit
elif [[ ${#call_subfield} -gt 1 ]] ; then echo "ERROR - definice PODpole nemuze mit vic nez 1 znak"; exit
fi

#prepinac idno sysno
match_id_def="1"
read -p "Podle ceho je linkovan SK (1 - IDno (pole 001), 2 - sysno) : " -i "$match_id_def" -e match_id
if [ "$match_id" = "1" ]; then match_id='idno'
elif [ "$match_id" = "2" ]; then match_id='sysno'
else  echo "ERROR - unrecognised value: $match_id (should be 1 or 2)"; exit; fi

#output file
output_file_def='chybi_podpole_x'
read -p "Vystupni soubor : " -i "$output_file_def" -e output_file
cp /dev/null $output_file

#log
log_file_def="$alephe_dev/alephe/scratch/chybi_podpole_x.log"
read -p "Log soubor : " -i "$log_file_def" -e log_file
cp /dev/null $log_file


echo START `date` >>$log_file
#extract call_no field from local aleph seq file
echo "Extracting fields with call numbers local SEQ file $aleph_seq" | tee -a $log_file
grep "^......... $call_field" $aleph_seq >/tmp/sk910_local.callno
sed -i 's/\$\$[^'"$call_subfield"'][^\$]\{2\}\+//g' /tmp/sk910_local.callno


#extract call numbers from sk err file
echo "Extracting call numbers from SK file $sk910file" | tee -a $log_file
linetotal=$(wc -l <"$sk910file")
linecurrent=1;
cp /dev/null "$output_file"
cp /dev/null "$output_file".err
while read line; do
   if [[ $((linecurrent % 100)) -eq 0 ]]; then
      echo "    line $linecurrent (of $linetotal) - "$(( (linecurrent*100) / linetotal ))'%'
   elif [[ $linecurrent -eq 1 ]]; then
      echo "    line 1 (of $linetotal) - 0%"
   fi
   is_910=$(echo "$line" | grep '^......... 910' -c | bc)
   if [[ $is_910 -ne 0 ]]; then
      is_call_no=$(echo "$line" | grep '\$\$'"$call_subfield" -c | bc)
      if [[ $is_call_no -eq 0 ]]; then
         echo "	WARNING - line $line contains NO call no. in subfield B" | tee -a "$log_file"
         echo "$line - radek neobsahuje signaturu (podpole b)" >>"$output_file".err
      elif [[ $is_call_no -gt 1 ]]; then
         echo "	WARNING - line $line contains more then one call nos. in subfields B" | tee -a "$log_file"
         echo "$line - radek neobsahuje vice nez jednu signaturu (podpole b)" >>"$output_file".err
      else #ok
         #get callno and look for it in local data
         call_no=$(echo "$line" | grep '\$\$'$call_subfield'[^\$]\+' -o | sed 's/\$\$'$call_subfield'//')
         call_no_local=$(grep "$call_no" /tmp/sk910_local.callno)
         call_no_local_count=$(echo "$call_no_local" | wc -l | bc)
         if [[ $call_no_local_count -eq 0 ]]; then
            echo "	WARNING - Call number $call_no not found in local data $aleph_seq" | tee -a "$log_file"
            echo "$line - signatura $call_no nedohledana v lokalnich datech" >>"$output_file".err
         elif [[ $call_no_local_count -gt 1 ]]; then
            echo "	WARNING - Call number $call_no not found more than once in local data $aleph_seq" | tee -a "$log_file"
            echo "$line - signatura $call_no nalezena vic nez 1x v lokalnich datech, konretne:" >>"$output_file".err
            echo "$call_no_local" | sed 's/^/      /' >>"$output_file".err
         else #ok
            if [ $match_id = 'sysno' ]; then 
               x=$(echo "$call_no_local" | awk '{print $1;}')
                echo "$line"'$$x'"$x" >>"$output_file"
            else #idno
               sysno=$(echo "$call_no_local" | awk '{print $1;}')
               x=$(grep '^'$sysno' 001  ' "$aleph_seq" | sed 's/^......... 001   L //'  )
               x_count=$(echo "$x" | wc -w | bc)
               if [[ $x_count -ne 1 ]]; then 
                  echo "	ERROR - sysno $sysno has none ore more than one (namely $x_count) occurences of field 001" | tee -a "$log_file"
                  echo "$x" | tee -a "log_file"
                  echo "$line - error - odpovida sysnu $sysno, ale nalezen zadny nebo vice nez 1 vyskyt pole 001"  >>"$output_file".err
               else #ok
                  echo "$line"'$$x'"$x" >>"$output_file"
               fi
            fi
         fi
      fi
   fi
   linecurrent=$((++linecurrent))
done <"$sk910file"

gut_count=$(wc -l <"$output_file" | bc)
err_count=$(wc -l <"$output_file".err | bc)
echo | tee -a $log_file
echo END `date` >>$log_file
echo "Log file is : $log_file"
if [[ $gut_count -eq 0 ]]; then
   echo "Zadny dohledany zaznam - sysno, neni nic, co by se dalo poslat automaticky do SK" | tee -a "$log_file"
else
   echo "Vysledek -pole 910 s doplnenym $match_id vhodne pro predani NK pro upload do SK je : $output_file (celkem $gut_count zaznamu)" | tee -a "$log_file"
fi
if [[ $err_count -eq 0 ]]; then
   echo "Zadna chyba ani, problem." | tee -a "$log_file"
else
   echo "Chybove a problematicke pripady k rucnimu provereni najdete: $output_file".err" (celkem $err_count zaznamu)" | tee -a "$log_file"
fi
rm -f /tmp/sk910*



