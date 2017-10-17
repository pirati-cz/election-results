#!/usr/bin/env bash

conn='mysql --user=election -pelection -D election'
dataUrl=https://volby.cz/pls/ps2013/vysledky
file=vysledky

function firstRun() {
	if $conn -e "SHOW databases;"; then
		echo "Mysql ok"
	else	
		echo "No mysql, create..."
		sudo mysql < create.sql
		$conn < parseXml.sql
	fi;
}


function updateData() {
	rm "$file"
	wget "$dataUrl"

	iconv -f CP1250 -t utf8 "$file" | tail -n +2 > input.xml

	$conn -e "call ParseXml('$(cat input.xml)')"
}

firstRun
updateData
sleep 20
updateData
