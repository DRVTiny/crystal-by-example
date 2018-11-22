#!/bin/bash
pid=
get_crystal_pid () {
	pid=$(pgrep -a crystal | sed -nr 's%^([0-9]+)\s+.+\.tmp$%\1%p')
	[[ $pid ]]
}

wait4crystal () {
	echo -n 'Waiting for crystal process to be up: '
	until get_crystal_pid; do
		echo -n '='
		sleep 0.2
	done
	echo -e "\nDONE"	
}

while :; do
	wait4crystal
	while :; do
		[[ -d /proc/$pid ]] || break
		kill -HUP $pid
	done
done
