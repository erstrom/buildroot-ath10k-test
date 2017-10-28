#! /bin/sh

PORT=1234

which iperf
[ $? -ne 0 ] && echo "iperf missing. Aborting!" && exit 1

iperf --server -p $PORT
