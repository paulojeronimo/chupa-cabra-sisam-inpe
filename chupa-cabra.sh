#!/usr/bin/env bash
set -eou pipefail

cd "`dirname "$0"`"

echo "Environment settings:"
set -x
PWD=$PWD
DATA_DIR=${DATA_DIR:-tmp/data}
FAKE_MODE=${FAKE_MODE:-false}
FAKE_SLEEP_TIME=${FAKE_SLEEP_TIME:-0.05}
PARALLEL=${PARALLEL:-2}
INITIAL_YEAR=${INITIAL_YEAR:-2000}
FINAL_YEAR=${FINAL_YEAR:-2018}
INITIAL_MONTH=${INITIAL_MONTH:-01}
FINAL_MONTH=${FINAL_MONTH:-12}
GDRIVE_DIR=${GDRIVE_DIR:-~/Google\ Drive/tmp/queimadas}
{ set +x; } 2> /dev/null

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
	local file_name=$DATA_DIR/${uf}/${uf}_${year}_${month}.csv
	local error_file=`mktemp`

	echo "File $file_name is being generated ..."
	$FAKE_MODE && {
		sleep $FAKE_SLEEP_TIME
	} || {
		! [ -f $file_name ] || {
			echo "Skipping generation of $file_name (it already exists)!"
			return
		}
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
			-d 'variaveis=vento' \
			-d 'variaveis=temp_ar' \
			-d 'variaveis=umid_ar' \
			-d 'variaveis=prec' \
			-d 'variaveis=num_focos' 2> $error_file > $file_name || {
			echo "File $file_name could not be generated!"
			cp $error_file $file_name.error.txt
			return
		}
	}
	echo "File $file_name generated!"
}

sync_with_gdrive() {
	echo -n "Synchronizing 7z files from $DATA_DIR to \"$GDRIVE_DIR\" ..."
	rsync -a $DATA_DIR/*.7z "$GDRIVE_DIR"/
	echo ok
}

remove_files_with_zero_size() {
	local uf=$1
	local f
	for f in $(find $DATA_DIR/$uf -type f -size 0)
	do
		echo "Removing file $f because it has 0 size!"
		rm -f $f
	done
}

request_and_save_by_uf() {
	local initial_date
	local final_date
	local uf=$1
	local year
	local month
	local file_name=$DATA_DIR/$uf.7z

	echo "Starting generation for UF $uf ..."
	$FAKE_MODE || {
		mkdir -p $DATA_DIR/$uf
		remove_files_with_zero_size $uf
	}
	for year in `eval "echo {$INITIAL_YEAR..$FINAL_YEAR}"`
	do
		! [ -f $file_name ] || {
			echo "Skipping generation of $file_name (it already exists)!"
			return
		}

		for month in $(eval "echo {$INITIAL_MONTH..$FINAL_MONTH}")
		do
			initial_date="01/$month/$year"
			final_date="$(final_day $month $year)/$month/$year"
			request_and_save $uf $initial_date $final_date
		done
	done
	$FAKE_MODE || {
		cd $DATA_DIR/$uf
		# https://superuser.com/a/742034
		7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../$(basename $file_name) *.csv &> /dev/null
		cd - &> /dev/null
		echo "File $file_name generated!"
		cp $file_name $GDRIVE_DIR/
		echo "File $file_name copied to \"$GDRIVE_DIR\"!"
		rm -rf $DATA_DIR/$uf
		echo "Directory $DATA_DIR/$uf removed!"
	}
	echo "Generation for UF $uf finished!"
}

mkdir -p "$DATA_DIR"

[ -f ufs.txt ] || cp all_ufs.txt ufs.txt

if [ "${1:-}" ]
then
	ufs=$1
else
	ufs="`cat ufs.txt`"
fi

echo "Start time: `date`"
number_of_ufs=`cat ufs.txt | tr ' ' '\n' | wc -l | xargs`
echo "Number of UFs to download information: $number_of_ufs"

sync_with_gdrive

count=0
total=0
for uf in $ufs
do
	request_and_save_by_uf $uf &
	pids[${count}]=$!
	(( count+=1 ))
	(( total+=1 ))
	if (( count % PARALLEL == 0 )) || (( total == number_of_ufs ))
	then
		echo "Waiting for ${#pids[@]} concurrent executions ..."
		wait ${pids[*]}
		unset pids
		count=0
	fi
done
echo "Information for $total UFs was downloaded!"
echo "End time: `date`"
