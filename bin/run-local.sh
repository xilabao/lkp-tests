#!/bin/bash

[ -n "$LKP_SRC" ] || export LKP_SRC=$(dirname $(dirname $(readlink -e -v $0)))
export TMP=/tmp/lkp
export PATH=$PATH:$LKP_SRC/bin
export BENCHMARK_ROOT=/lkp/benchmarks

usage()
{
	cat <<EOF
Usage: run-local [-o RESULT_ROOT] JOB_SCRIPT

options:
    -o  RESULT_ROOT         dir for storing all results
EOF
	exit 1
}

set_local_variables()
{
	export kconfig=${kconfig:-defconfig}
	export commit=${commit:-$(uname -r)}

	export compiler=$(grep -o "gcc version [0-9]*" /proc/version | awk '{print "gcc-"$NF}')
	export compiler=${compiler:-default_compiler}
	export rootfs=$(grep -m1 ^ID= /etc/os-release | awk -F= '{print $2}')
	export rootfs=${rootfs:-default_rootfs}

	export testbox=$HOSTNAME
	export tbox_group=$HOSTNAME
	export nr_cpu=$(grep -c ^processor /proc/cpuinfo)
	local x=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
	export memory=$((x/1024/1024 + 1))G
}

update_export_variables()
{
	local cur_variables=$(export -p | sed -E 's/(export |declare -x )//g')
	local new_variables=$(bash -c "
	. $job_script
	export_top_env
	export -p | sed -E 's/(export |declare -x )//g'
	")

	local tmp_job_script=$(mktemp -u /tmp/job-script.XXXXXXXXX)
	cp $job_script $tmp_job_script
	for var in $(echo "$cur_variables" | grep -v -f <(echo "$new_variables"))
	do
		local var_name=${var%%=*}
		grep -q "export $var_name=" $tmp_job_script &&
		sed -i "s/export $var_name=.*$/export $var/g" $tmp_job_script
	done
	mv $tmp_job_script $RESULT_ROOT/job.sh &&
	job_script=$RESULT_ROOT/job.sh
}

while getopts "o:" opt
do
	case $opt in
	o ) opt_result_root="$OPTARG" ;;
	? ) usage ;;
	esac
done

shift $(($OPTIND-1))
job_script=$1
[ -n "$job_script" ] || usage
job_script=$(readlink -e -v $job_script)

set_local_variables

eval $(grep "export result_root_template=" $job_script)
if [[ $opt_result_root ]]; then
	mkdir -p -m 02775 $opt_result_root
	export RESULT_ROOT=$(readlink -e -v $opt_result_root)
elif [[ $RESULT_ROOT ]]; then
	mkdir -p -m 02775 $RESULT_ROOT
elif [[ $result_root_template ]]; then
	for i in {0..99}
	do
		export RESULT_ROOT=$(eval "echo $result_root_template")/$i
		[[ -d $RESULT_ROOT ]] && continue
		mkdir -p -m 02775 $RESULT_ROOT &&
		echo "result_root: $RESULT_ROOT" &&
		break
	done
else
	echo "$0 exit due to RESULT_ROOT is not specified, you can use either"
	echo "\"-o RESULT_ROOT\" or \"export RESULT_ROOT=<result_root>\" to specify it.\n"
	usage
fi
unset result_root_template

export TMP_RESULT_ROOT=$RESULT_ROOT
export LKP_LOCAL_RUN=1
rm -rf $TMP
mkdir $TMP

update_export_variables

$job_script run_job

$LKP_SRC/bin/post-run
$LKP_SRC/bin/event/wakeup job-finished
