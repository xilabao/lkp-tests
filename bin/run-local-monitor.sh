#!/bin/sh

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
    -s  TEST_SUITE          specify the test name, e.g. sleep_10
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

while getopts "o:s:" opt
do
	case $opt in
	o ) opt_result_root="$OPTARG" ;;
	s ) opt_test_suite="$OPTARG" ;;
	? ) usage ;;
	esac
done

shift $(($OPTIND-1))
job_script=$1
[ -n "$job_script" ] || usage
job_script=$(readlink -e -v $job_script)

shift
mytest="${@}"
mytest=$(echo $mytest | sed 's/^.*-- //')

[[ $mytest ]] && export MY_TEST_CMDLINE=$mytest
[[ $opt_test_suite ]] || opt_test_suite="default"

. $job_script export_top_env
set_local_variables

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

export TMP_RESULT_ROOT=$RESULT_ROOT
export LKP_LOCAL_RUN=1
rm -rf $TMP
mkdir $TMP

set > $RESULT_ROOT/env

[[ -f $job_script ]] && cp $job_script $RESULT_ROOT/job.sh
[[ -f $job_script.yaml ]] && cp $job_script.yaml $RESULT_ROOT/job.yaml

$job_script run_job

$LKP_SRC/bin/post-run
$LKP_SRC/bin/event/wakeup job-finished

[[ $(realpath $RESULT_ROOT) != $(pwd) ]] && ln -sfn $RESULT_ROOT result_root
