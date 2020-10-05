#!/usr/bin/env bash

DATA_DIR=${DATA_DIR:-tmp/data}

final_day() {
	local m=$1
	local y=$2
	local d
	case "$m" in
		01|03|05|07|08|10|12) d=31;;
		02)
			case "$y" in
				2000|2004|2008|2012|2016) d=29;;
				*) d=28;;
			esac
			;;
		*) d=30;;
	esac
	echo -n $d
}

request_and_save() {
	local uf=$1
	local inicio=$2
	local final=$3
	local file_name=$DATA_DIR/${uf}_${month}_${year}.csv

	echo "Gerando o arquivo $file_name ..."
	curl -X POST http://queimadas.dgi.inpe.br/queimadas/sisam/v2/api/variaveis \
		-d "uf=$uf" \
		-d "inicio=$inicio"  \
		-d "final=$final" \
		-d 'horarios=0' \
		-d 'horarios=6' \
		-d 'horarios=12' \
		-d 'horarios=18' \
		-d 'municipios=-1' \
		-d 'variaveis=conc_co' \
		-d 'variaveis=conc_o3' \
		-d 'variaveis=conc_no2' \
		-d 'variaveis=conc_so2' \
		-d 'variaveis=conc_pm' \
		-d 'variaveis=conc_vento' \
		-d 'variaveis=temp_ar' \
		-d 'variaveis=umid_ar' \
		-d 'variaveis=prec' \
		-d 'variaveis=num_focos' 2> /dev/null > $file_name
}

cd "`dirname "$0"`"
mkdir -p "$DATA_DIR"

[ -f ufs.txt ] || cp all_ufs.txt ufs.txt

if [ "$1" ]
then
	ufs=$1
else
	ufs="`cat ufs.txt`"
fi

for uf in $ufs
do
	for year in {2000..2018}
	do
		for month in {01..12}
		do
			initial_date="01/$month/$year"
			final_date="$(final_day $month $year)/$month/$year"
			request_and_save $uf $initial_date $final_date
		done
	done
	# https://superuser.com/a/742034
	7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on $DATA_DIR/$uf.7z $DATA_DIR/$uf*.csv
	rm $DATA_DIR/$uf*.csv
done
