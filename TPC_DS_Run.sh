#!/bin/bash

#-------------------------------------------------------------------------------

# Copyright 2015 Actian Corporation
 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
 
# http://www.apache.org/licenses/LICENSE-2.0
 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#-------------------------------------------------------------------------------

# This script will Create, Load and Execute a single stream 'TPC-DS Style Benchmark'
#
# The script should be run as user 'actian' for Vector and VectorH installations.
#
# Parameters
#     $1 - The size of the data to be used in the test. 1 = 1Gb, 100 = 100Gb.
#          This value is used to calculate the total data set size 
#              Data Set Size = No. of Nodes x THIS Parameter 
#          If this parameter is not passed the default is to generate 1Gb per node.
#          For Vector the No. of Nodes is always 1.
#
#
# PLEASE NOTE 
#
#     This is not intended to represent an official TPC benchmark. 
#
#     It does however correctly use dsdgen and dsqgen to generate the data and 
#     TPC DS benchmark SQL from the TPC templates. 
#     It is simply intended as a useful tool for Vector/VectorH performance evaluation.
#
#     Only minor modfications where required to the TPC Template SQL. This was in 
#     relation to SQL statements where a number of days are added.
#     For these statements in Vector/VectorH quotes must be added but this in no 
#     way affects the itegrity of the SQL. e.g. 30 days --> '30 days'
#     Templates updated accordingly:
#         5,12,16,20,21,32,37,40,77,80,82,92,94,95 and 98
#
#
# The results of the TPC style tests can be found in ${LOGDIR} where this by default
# is the directory 'LOG_FILES' directly below the install directory. Output in 
# this directory includes:
#
#     1. TPC_DS_Summary_Results.txt   - Summary of the run with run timings.
#     2. TPC_DS_query'nn'_Results.out - The output from each benchmark SQL run.

#-------------------------------------------------------------------------------

set -e

echo ""
echo "TPC-DS Style Benchmark run starting"
echo ""

# Essential control variables

INSTALL_DIR=/home/actian
TPC_DB=tpc_db

HOSTNAME=`hostname`
OSVERSION=`uname`

SOURCE_DIR=SOURCE_TO_BUILD
TABLE_DIR=CREATE_TABLE_DDL
DATA_DIR=DATA_GENERATED
TEMP_DIR=TPC_SQL_TEMPLATES
SQL_DIR=TPC_SQL_SCRIPTS
LOG_DIR=LOG_FILES
LOG_FILE=${LOG_DIR}/TPC_DS_Summary_Results.txt

GEN_DATA_SCALE=${1}
GEN_DATA_THREADS=4

# Calculate the no. of parttions to be used for the larger Vector/vectorH Tables.

    # Default number of nodes to 1, in case this is running with single-node 
    # Vector installation, not Vector-H
    if [ -f $II_SYSTEM/ingres/files/hdfs/slaves ]; then
        NODES=`cat $II_SYSTEM/ingres/files/hdfs/slaves | wc -l`
    else
        NODES=1
    fi

    CORES=`cat /proc/cpuinfo | grep 'cpu cores' | sort | uniq | cut -d: -f 2`
    CPUS=`cat /proc/cpuinfo | grep 'physical id' | sort | uniq | wc -l`

    # Switch errors off as zero divide produces non-zero result code
    set +e
    PARTITIONS=`expr ${CORES} "*" ${CPUS} "*" ${NODES} "/" 2`
    set -e

    # Default partitions to 2 where calc yields 0 or 1 
    if [ "${PARTITIONS}" -lt "2" ]; then
        PARTITIONS=2
    fi

# Parameter Validation

if [ "${GEN_DATA_SCALE}" == "" ]; then
    GEN_DATA_SCALE=${NODES}

    echo ""
    echo "No data set size passed as parameter 1."
    echo "Generated data set calculated as 1 Gb / Node = ${GEN_DATA_SCALE}Gb."
    echo ""
else
    GEN_DATA_SCALE=`expr ${NODES} "*" ${1}`

    echo ""
    echo "Generated date set calculated as ${1} Gb / Node = ${GEN_DATA_SCALE}Gb."
    echo ""
fi


# 1. Initialisation
#     - Install gcc, git and recode if not already installed.
#     - Create required sub-directories.

echo ""
echo "Step 1 - Installing gcc and recode (if not already installed)."
echo ""

sudo yum -y install gcc

sudo yum -y install recode

if [ ! -d ${DATA_DIR} ]; then
    mkdir ${DATA_DIR}
fi

if [ ! -d ${SQL_DIR} ]; then
    mkdir ${SQL_DIR}
fi

if [ ! -d ${LOG_DIR} ]; then
    mkdir ${LOG_DIR}
fi

# 2. Tidy up any previous run

echo ""
echo "Step 2 - Tidying up any previous run files etc."
echo ""

rm -rf rm ${PWD}/${DATA_DIR}/*.dat
rm -rf rm ${PWD}/${SQL_DIR}/*.sql

rm -f ${LOG_DIR}/TPC_DS*.out
rm -f ${LOG_DIR}/TPC_DS_Gen_Data*.log
rm -f ${LOG_DIR}/Vector_Load.log

rm -f ${LOG_FILE}

set +e
destroydb ${TPC_DB}
set -e

# 3. Build the dsgen & dsqgen excecutables

echo ""
echo "Step 3 - Building dsgen and dsqgen required to generate test data."
echo ""

cd ${PWD}/${SOURCE_DIR}
rm -f *.o
make > dsgen_dsqgen_build.log

cp tpcds.idx ${PWD}/../
cp dsdgen ${PWD}/../
cp dsqgen ${PWD}/../

cd ..

# 4. Generate the test data

echo ""
echo "Step 4/1 - Generating the test data. This make take a while."
echo ""

# Kill any data generation processes possibly running from a previous run
for process_id in $(ps -ef | grep TPC_DS_Gen_Data.sh | grep -v grep | awk -F ' ' '{print $2}'); do
    echo "killing ${process_id}"
    kill ${process_id}
    sleep 1
done

# Launch a data generator for each of the parallel threads required 
for thread_no in $(seq 1 ${GEN_DATA_THREADS}); do
    nohup ${PWD}/TPC_DS_Gen_Data.sh ${GEN_DATA_THREADS} ${thread_no} ${GEN_DATA_SCALE} > ${LOG_DIR}/TPC_DS_Gen_Data${thread_no}.log 2>&1 < ${LOG_DIR}/TPC_DS_Gen_Data${thread_no}.log &
done

# Monitor the progress of the data generation threads and continue when ALL complete
count=1

while [ "${count}" -gt "0" ]; do
    echo -ne "."
    sleep 5
    count=$(ps -ef | grep TPC_DS_Gen_Data.sh | grep -v grep | wc -l)
done

echo ""
echo ""
echo "Step 4/2 - Fixing a character set issue with the customer file."
echo ""

for data_file in $(ls ${PWD}/${DATA_DIR}/customer_[1-${GEN_DATA_THREADS}]_${GEN_DATA_THREADS}.dat); do
    cat ${data_file} | recode iso-8859-1..u8 > ${data_file}.new
    mv ${data_file} ${data_file}.bak
    mv ${data_file}.new ${data_file}
done

# 5. Generate the SQL from the TPC templates

echo ""
echo "Step 5 - Generating SQL from TPC templates."
echo ""

for template_file in $(cat ${PWD}/${TEMP_DIR}/templates.lst); do

    template_name=`echo ${template_file} | awk -F '.' '{print $1}'`

    ./dsqgen -template ${template_file} -directory ${TEMP_DIR} -output ${SQL_DIR} -dialect vector -scale ${GEN_DATA_SCALE} -quiet Y

    mv ${SQL_DIR}/query_0.sql ${SQL_DIR}/${template_name}.sql

done

# 6. Create and populate the Vector database

echo ""
echo "Step 6 - Creating the TPC database schema and populating from the generated data."
echo ""

createdb ${TPC_DB}

for sql_file in $(ls ${PWD}/${TABLE_DIR}/*.sql); do

    # Create table with the appropriate partitions 
    table_name=`echo ${sql_file} | awk -F '.' '{print $2}'`

    echo "Creating and loading table : ${table_name}"

    DDL_TO_RUN=`cat ${sql_file} | sed "s/#PARTITIONS#/${PARTITIONS}/"; echo "\g"`

    sql -uactian ${TPC_DB} >> ${LOG_DIR}/Vector_Load.log <<EOF
${DDL_TO_RUN}
EOF

    # Populate the table from any available generated data (May not always be?)
    vwload -m -t ${table_name} -uactian ${TPC_DB} ${PWD}/${DATA_DIR}/${table_name}_[0-9]*.dat >> ${LOG_DIR}/Vector_Load.log

done

# 7. Run the TPC SQL

echo ""
echo "Step 7 - Running the SQL Tests."
echo ""

echo "TPC DS Style SQL Performance Test Results" > ${LOG_FILE}
echo "-----------------------------------------" >> ${LOG_FILE}
echo ""                                          >> ${LOG_FILE}

for sql_file in $(ls ${PWD}/${SQL_DIR}/*.sql); do

    sql_name=`echo ${sql_file} | awk -F 'TPC_SQL_SCRIPTS/' '{print $2}' | awk -F '.' '{print $1}'`
    sql_no=`echo ${sql_file} | awk -F 'TPC_SQL_SCRIPTS/' '{print $2}' | awk -F '.' '{print $1}' | sed 's/Query//'`

    echo "Step 6/${sql_no} - Running SQL Test ${sql_name}."

    # Note time at start of run
    if [ "$OSVERSION" == "Linux" ]; then
        Start_Time="$(date +%s%N)"
    else
        Start_Time="$(date +%s)"
    fi

    # Run the SQL
    sql_to_run=`cat ${sql_file}; echo "\g"`

    sql -uactian ${TPC_DB} > ${LOG_DIR}/TPC_DS_${sql_name}_Results.out <<EOF
${sql_to_run}
EOF

    # Time at end of run and hence calculate duration
    if [ "$OSVERSION" == "Linux" ]; then
        Run_Time="$(($(date +%s%N)-${Start_Time}))"
        Run_Secs="$((${Run_Time}/1000000000))"
        Run_Msec="$((${Run_Time}/1000000))"
    else
        #must be OSX which doesn't have nano-seconds
        Run_Time="$(($(date +%s)-${Start_Time}))"
        Run_Secs=${Run_Time}
        Run_Msec=0
    fi

    # Log the results - run time or FAILED
    if [ `grep "^E_US" ${LOG_DIR}/TPC_DS_${sql_name}_Results.out | wc -l` -gt 0 ]; then
        printf "${sql_name} FAILED\n" >> ${LOG_FILE}
    else
        printf "${sql_name} run time is : %02d:%02d:%02d.%03d\n" "$((${Run_Secs}/3600%24))" "$((${Run_Secs}/60%60))" "$((${Run_Secs}%60))" "${Run_Msec}" >> ${LOG_FILE}
    fi

done

echo ""
echo "TPC-DS Style Benchmark run completed successfully"
echo ""

#------------------------------------------------------------------------------#
#---------------------------- End of Shell Script -----------------------------#
#------------------------------------------------------------------------------#
