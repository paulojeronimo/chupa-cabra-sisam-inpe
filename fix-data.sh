#!/usr/bin/env bash
set -eou pipefail

_7z-files() {
	local zips=$(find . -type f -name '*.7z')
	local d
	echo "Fixing 7z files ..."
	local z
	for z in $zips
	do
		d=${z#./}
		d=${d%.7z}
		echo "Fixing $z ..."
		mkdir $d
		cd $d
		7z x ../$z
		rm ../$z
		mv tmp/data/* .
		rename 's/(..)_(..)_(....)/$1_$3_$2/g' *
		rm -rf tmp/data
		7z a -t7z -m0=lzma -mx=9 -mfb=64 -md=32m -ms=on ../$d.7z *
		cd ..
		rm -rf $d
		echo -e "$z Fixed!\n\n"
	done
}

_csv-files() {
	local dirs=$(find . -type f -name '*.csv' | sed 's/^\.\/\(..\).*/\1/g' | sort | uniq)
	echo "Fixing CSV files ..."
	local d
	for d in $dirs
	do
		mkdir $d
		mv $d*.csv $d
		cd $d
		rename 's/(..)_(..)_(....)/$1_$3_$2/g' *
		cd ..
	done
}

cd `dirname "$0"`/tmp/data
type _${1:-}-files &> /dev/null && _$1-files || {
	echo "Usage: $0 [7z|csv]"
}
