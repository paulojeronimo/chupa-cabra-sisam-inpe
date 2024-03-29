#!/usr/bin/env bash
# References:
#	Ref1:
#		- https://superuser.com/a/742034
#	Ref2:
#		- https://www.gnu.org/software/bash/manual/html_node/Redirections.html
#		- https://tldp.org/LDP/abs/html/io-redirection.html
#		- https://serverfault.com/a/103569
#		- https://serverfault.com/a/477337
#		- https://gist.github.com/gin1314/3697341
#		- https://unix.stackexchange.com/questions/159513/what-are-the-shells-control-and-redirection-operators
#	Ref3:
#		- https://stackoverflow.com/a/2371288	
set -eou pipefail
BASE_DIR=`cd "$(dirname "$0")";pwd`
INSTANCE=`date +%s`
LOG_DIR=${LOG_DIR:-tmp}
LOG_FILE=${LOG_FILE:-`basename "$0" .sh`.$INSTANCE.log}

# Configure functions for the execution environment
case "$OSTYPE" in
	darwin*)
		date() { gdate "$@"; }
		;;
esac

{
# Ref3
echo "Start time: $(date -d @$INSTANCE)"
echo "Configured settings:"
} > "$LOG_DIR/$LOG_FILE"

# Ref2
exec 3>&2
exec 2>> "$LOG_DIR/$LOG_FILE"
set -x
BASE_DIR=$BASE_DIR
INSTANCE=$INSTANCE
LOG_DIR=$LOG_DIR
LOG_FILE=$LOG_FILE
CONFIG_DIR=${CONFIG_DIR:-.}
DATA_DIR=${DATA_DIR:-tmp/data}
FAKE_MODE=${FAKE_MODE:-false}
FAKE_SLEEP_TIME=${FAKE_SLEEP_TIME:-0.05}
PARALLEL=${PARALLEL:-2}
INITIAL_YEAR=${INITIAL_YEAR:-2000}
FINAL_YEAR=${FINAL_YEAR:-2018}
INITIAL_MONTH=${INITIAL_MONTH:-01}
FINAL_MONTH=${FINAL_MONTH:-12}
GDRIVE_SYNC=${GDRIVE_SYNC:-false}
GDRIVE_DIR=${GDRIVE_DIR:-~/Google\ Drive/tmp/queimadas}
{ set +x; } 2> /dev/null
exec 2>&3
exec 3>&-
cat "$LOG_DIR/$LOG_FILE"

log() {
	echo "$(date) → $@"
}

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

	log "File $file_name is being generated ..."
	$FAKE_MODE && {
		sleep $FAKE_SLEEP_TIME
	} || {
		! [ -f $file_name ] || {
			log "Skipping generation of $file_name (it already exists)!"
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
			log "File $file_name could not be generated!"
			cp $error_file $file_name.error.txt
			return
		}
	}
	log "File $file_name generated!"
}

sync_with_gdrive() {
	echo -n "Synchronizing 7z files from $DATA_DIR to \"$GDRIVE_DIR\" ... "
	! [ -n "`ls -A $DATA_DIR/*.7z 2>&-`" ] || rsync -a $DATA_DIR/*.7z "$GDRIVE_DIR"/
	echo ok
}

remove_invalid_files() {
	local uf=$1
	local f
	for f in $(find $DATA_DIR/$uf -type f -name '*.csv')
	do
		[ -s $f ] || {
			log "Removing file $f because it has 0 size!"
			rm -f $f
			continue
		}
		grep -q "^datahora,co_ppb,no2_ppb.*,mun_lon,mun_uf_nome" <(head -1 $f) || {
			log "Removing file $f because it has an invalid header!"
			rm -f $f
		}
	done
}

request_and_save_by_uf() {
	local initial_date
	local final_date
	local uf=$1
	local year
	local month
	local file_name=$DATA_DIR/$uf.7z

	log "Starting generation for UF $uf ..."
	$FAKE_MODE || {
		[ -f $file_name ] || mkdir -p $DATA_DIR/$uf
		remove_invalid_files $uf
	}
	for year in `eval "echo {$INITIAL_YEAR..$FINAL_YEAR}"`
	do
		! [ -f $file_name ] || {
			log "Skipping generation of $file_name (it already exists)!"
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
		log "Building $file_name ..."
		# Ref1
		7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../$(basename $file_name) *.csv &> /dev/null
		cd - &> /dev/null
		log "File $file_name generated!"
		! $GDRIVE_SYNC || {
			cp $file_name "$GDRIVE_DIR"/
			log "File $file_name copied to \"$GDRIVE_DIR\"!"
		}
		rm -rf $DATA_DIR/$uf
		log "Directory $DATA_DIR/$uf removed!"
	}
	log "Generation for UF $uf finished!"
}

mkdir -p "$DATA_DIR"

[ -f "$CONFIG_DIR"/ufs.txt ] || cp all_ufs.txt "$CONFIG_DIR"/ufs.txt

if [ "$#" -ne 0 ]
then
	ufs="$@"
	number_of_ufs=$#
else
	ufs="`cat "$CONFIG_DIR"/ufs.txt`"
	number_of_ufs=`cat "$CONFIG_DIR"/ufs.txt | tr ' ' '\n' | wc -l | xargs`
fi

{
cd "$BASE_DIR"
echo "Number of UFs to download information: $number_of_ufs"

! $GDRIVE_SYNC || sync_with_gdrive

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
		log "Waiting for ${#pids[@]} concurrent executions ..."
		wait ${pids[*]}
		unset pids
		count=0
	fi
done
log "Information for $total UFs was downloaded!"
echo "End time: `date`"
# https://stackoverflow.com/questions/8903239/how-to-calculate-time-elapsed-in-bash-script
#echo "Elapsed time: "
} |& tee -a "$LOG_DIR/$LOG_FILE"
