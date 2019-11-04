# How to run local script in a minimal environment
## Prepare lkp environment (the feature hasn't been merged into the mainline)
```
[root@localhost ~]# dnf install gcc make git -y
[root@localhost ~]# git clone https://github.com/xilabao/lkp-tests.git && cd lkp-tests && git checkout run-local-script
[root@localhost lkp-tests]# make
[root@localhost lkp-tests]# cd bin/event && make wakeup
[root@localhost ~]# export PATH=$PATH:"/usr/local/bin/"
```

## Install dependencies
```
[root@localhost ~]# dnf install perf procps which time -y
```

## Run job with attached monitor.sh and replace "sleep 10" to your own benchmark commands
```
# option "-s" could set the test suite name, and you could use "-o" to specify the result root directory
# job-scripts/monitor.sh doesn't contain perf
[root@localhost lkp-tests]# lkp run-monitor -s sleep_10 job-scripts/monitor.sh -- sleep 10
result_root: /lkp/result/mytest/sleep_10/localhost.localdomain/fedora/defconfig/gcc-8/5.2.0-rc3-8e44c7840479/0
2019-10-27 03:21:46
wait for background processes: 21401 21409 21405 21412 21418 slabinfo buddyinfo zoneinfo proc-vmstat meminfo

# job-scripts/monitor-perf.sh contains 'perf-stat', you can choose other perf tools from lkp-tests/monitors/perf-*
# then update both monitor-perf.sh and monitor-perf.yaml
[root@localhost lkp-tests]# lkp run-monitor -s sleep_10 job-scripts/monitor-perf.sh -- sleep 10
result_root: /lkp/result/mytest/sleep_10/localhost.localdomain/fedora/defconfig/gcc-8/5.2.0-rc3-8e44c7840479/1
2019-10-27 03:22:02
wait for background processes: 21658 21665 21661 21669 21674 21680 slabinfo buddyinfo zoneinfo proc-vmstat meminfo perf-stat
```

## Get the results
```
[root@localhost lkp-tests]# ls result_root -l
lrwxrwxrwx 1 root root 95 Oct 27 03:22 result_root -> /lkp/result/mytest/sleep_10/localhost.localdomain/fedora/defconfig/gcc-8/5.2.0-rc3-8e44c7840479/1
[root@localhost lkp-tests]# ls /lkp/result/mytest/sleep_10/localhost.localdomain/fedora/defconfig/gcc-8/5.2.0-rc3-8e44c7840479/1
buddyinfo.gz  env  job.sh  meminfo.gz  mytest  mytest.time  numa-meminfo.gz  numa-vmstat.gz  perf-stat.gz  proc-vmstat.gz  program_list  reproduce.sh  slabinfo  time  zoneinfo.gz
```
