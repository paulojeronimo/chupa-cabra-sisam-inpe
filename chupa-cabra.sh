#!/usr/bin/env bash

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
	local filename=${uf}_${month}_${year}.csv

	echo "Gerando o arquivo $filename ..."
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
		-d 'variaveis=num_focos' 2> /dev/null > $filename
}

if [ "$1" ]
then
	ufs=$1
else
	ufs="12 27 16 13 29 23 53 32 52 21 51 50 31 15 25 41 26 22 33 24 43 11 14 42 35 28 17"
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
done
