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
# The script can be run as any user provided it is registered as a Vector/VectorH 
# user and has sudo access.
#
# Parameters
#     $1 - Scale Factor. The size of the data to be used in the test. 1 = 1Gb, 100 = 100Gb.
#          If this parameter is not passed the default is to generate 1Gb per node.
#          For Vector the No. of Nodes is always 1.
#     $2 - Data Generation Threads. The no. of threads to be used for data generation.
#          Default = 4.
#          TPC provide no recommendation as to optimum threads but a decent rule of 
#          thumb is CPUs * COREs / 2
#
# PLEASE NOTE 
#
#     This is not intended to represent an official TPC benchmark. 
#
#     It is derived from TPC-DS 1.4.0 correctly use dsdgen and dsqgen to generate the 
#     data and the the TPC DS benchmark SQL from the TPC templates. 
#     It is simply intended as a useful tool for Vector/VectorH performance evaluation.
#     The results are NOT comparable with any published results.
#
#     Only minor modfications where required to the TPC Template SQL. This was in 
#     relation to SQL statements where a number of days are added in the context of 
#     the BETWEEN statement.
#     For these statements in Vector/VectorH quotes must be added but this in no 
#     way affects the itegrity of the SQL. e.g. 30 days --> '30 days'
#     Templates updated accordingly:
#         5,12,16,20,21,32,37,40,77,80,82,92,94,95 and 98
#
# The results of the TPC style tests can be found in ${LOGDIR} where this by default
# is the directory 'LOG_FILES' directly below the install directory. Output in 
# this directory includes:
#
#     1. TPC_DS_Summary_Results.txt   - Summary of the run with run timings.
#     2. TPC_DS_query'nn'_Results.out - The output from each benchmark SQL run.
#
# NOTES:
#
# For VectorH installations there is often limited none HDFS file space. As a result
# HDFS is utilised as this is usually plentiful and addtionally the vwload employed
# to load the generated data should perform better.
# Be aware that when generating very large databases, dsdgen still generates the chunks 
# of the large data files in parrallel so they co-exist in normal file space until they
# are copied to HDFS (It has not been possible to get dsdgen to create the data files
# directly in HDFS). As a result it will still be possible to exhaust normal file space.
#
# For the generation of larger data sets it is recommended that the no. of threads
# variable $THREADS be increased from the default of 4 in script TPC_DS_Run.sh.
#
# It is recommended that this be run against Vector or VectorH 4.2.2 or above.
# Specifically for VectorH patch 22101 or above should be applied.
# Known Problem - Query 14 can hang with earlier versions.
#
# The larger tables listed below are first staged then sorted on the hash key before 
# loading into the final table. The hash key (can be multiple attributes) can be changed
# by updating file 'sort_data_for_tables.txt'. 
#     1. catalog_returns
#     2. catalog_sales
#     3. customer_demographics
#     4. inventory
#     5. store_returns
#     6. store_sales
#     7. web_sales   
# It may be neceessary when creating very large databases to make addtional tables
# partitioned. This requires an appropriate sort key entry in the file above.
#

#-------------------------------------------------------------------------------

set -e

echo ""
echo "TPC-DS Style Benchmark run starting"
echo ""

# Essential control variables

export TPC_DB=tpc_db

HOSTNAME=`hostname`

SOURCE_DIR=SOURCE_TO_BUILD
TABLE_DIR=CREATE_TABLE_DDL
DATA_DIR=DATA_GENERATED
TEMP_DIR=TPC_SQL_TEMPLATES
export SQL_DIR=TPC_SQL_SCRIPTS
export LOG_DIR=LOG_FILES
export LOG_FILE=${LOG_DIR}/TPC_DS_Summary_Results.txt

SCALE_FACTOR=${1}
GEN_DATA_THREADS=${2}

set +e
hdfs dfsadmin -report > /dev/null 2>&1
if [ $? -eq 127 ]; then
    HDFS_INUSE=false
else
    export HDFS_INUSE=true
    export HDFS_URL=`hdfs getconf -confkey fs.default.name`
    export HDFS_DATA_DIR=tmp
fi
set -e

# Check user has access to a Vector/VectorH installation and sudo access

set +e

sql iidbdb > /dev/null 2>&1 <<EOF
\q
EOF

if [ $? -ne 0 ]; then
    echo "ERROR on start-up. The user does not appear to have access to a Vector/VectorH installation"
    exit 9
fi

sudo -v 2>&1 | grep "Sorry" > /dev/null

if [ $? -eq 0 ]; then
    echo "ERROR on start-up. The user does not appear to have access to sudo"
    exit 9
fi

set -e

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

if [ "${SCALE_FACTOR}" == "" ]; then
    SCALE_FACTOR=${NODES}

    echo ""
    echo "No scale factor passed as parameter 1."
    echo "Generated scale factor calculated as 1 Gb / Node = ${SCALE_FACTOR}Gb."
    echo ""
else
    echo ""
    echo "Scale factor used = ${SCALE_FACTOR}Gb."
    echo ""
fi

if [ "${GEN_DATA_THREADS}" == "" ]; then
    GEN_DATA_THREADS=4

    echo ""
    echo "No. of threads for data generation defaulted to ${GEN_DATA_THREADS}."
    echo ""
else
    echo ""
    echo "No. of threads for data generation is ${GEN_DATA_THREADS}."
    echo ""
fi


# 1. Initialisation
#     - Install gcc, git and recode if not already installed.
#     - Create required sub-directories.

echo ""
echo "Step 1 - Initialisation and Setup."
echo ""

sudo yum -y install gcc

sudo yum -y install recode

if [ ! -d ${DATA_DIR} ]; then
    mkdir ${DATA_DIR}
fi

set +e
if [ "${HDFS_INUSE}" = true ]; then
    hdfs dfs -mkdir  ${HDFS_URL}/${HDFS_DATA_DIR}
fi
set -e

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
if [ "${HDFS_INUSE}" = true ]; then
    hdfs dfs -rm -r -f -skipTrash ${HDFS_URL}/${HDFS_DATA_DIR}/*.dat > /dev/null 2>&1
fi
rm -rf rm ${PWD}/${SQL_DIR}/*.sql

rm -f ${LOG_DIR}/TPC_DS*.out
rm -f ${LOG_DIR}/TPC_DS_Gen_Data*.log
rm -f ${LOG_DIR}/Vector_Load.log

rm -f ${LOG_FILE}

set +e
destroydb ${TPC_DB} > /dev/null
set -e

# 3. Build the dsgen & dsqgen excecutables

echo ""
echo "Step 3 - Building dsgen and dsqgen required to generate test data."
echo ""

cd ${PWD}/${SOURCE_DIR}
rm -f *.o
make > dsgen_dsqgen_build.log 2>&1

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
    nohup ${PWD}/TPC_DS_Gen_Data.sh ${GEN_DATA_THREADS} ${thread_no} ${SCALE_FACTOR} > ${LOG_DIR}/TPC_DS_Gen_Data${thread_no}.log 2>&1 < ${LOG_DIR}/TPC_DS_Gen_Data${thread_no}.log &
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

for data_file in $(ls ${PWD}/${DATA_DIR}/customer_[1-9]*.dat); do

    cat ${data_file} | recode iso-8859-1..u8 > ${data_file}.new
    mv ${data_file}.new ${data_file}

    if [ "${HDFS_INUSE}" = true ]; then
        hdfs dfs -put ${data_file} ${HDFS_URL}/${HDFS_DATA_DIR}/.
        rm -f ${data_file}
    fi

done

# 5. Generate the SQL from the TPC templates

echo ""
echo "Step 5 - Generating SQL from TPC templates."
echo ""

for template_file in $(cat ${PWD}/${TEMP_DIR}/templates.lst); do

    template_name=`echo ${template_file} | awk -F '.' '{print $1}'`

    ./dsqgen -template ${template_file} -directory ${TEMP_DIR} -output ${SQL_DIR} -dialect vector -scale ${SCALE_FACTOR} -quiet Y

    mv ${SQL_DIR}/query_0.sql ${SQL_DIR}/${template_name}.sql

done

# 6. Create and populate the Vector database

echo ""
echo "Step 6 - Creating the TPC database schema and populating from the generated data."
echo ""

createdb ${TPC_DB}

optimze_tables=""

for sql_file in $(ls ${PWD}/${TABLE_DIR}/*.sql); do

    table_name=`echo ${sql_file} | awk -F '.' '{print $2}'`

    # Check if there are any sort keys specified for this table
    sort_keys=`cat ${PWD}/sort_data_for_tables.txt | grep "${table_name}|" | awk -F '|' '{print $2}'`

    # Create the table with the appropriate partitions if a sort key is specified.
    # The sort key is also used to HASH partition on.
    # For tables not specified for sorting not partitoned. 
    if [ "${sort_keys}" == "" ]; then
        echo "Creating and loading table : ${table_name}"
        DDL_TO_RUN=`cat ${sql_file}; echo "\g"`
    else
        echo "Creating and loading staging table : ${table_name}_stage"
        DDL_TO_RUN=`cat ${sql_file} | sed "s/${table_name}/${table_name}_stage/"`
        DDL_TO_RUN=${DDL_TO_RUN}" WITH PARTITION = ( HASH ON ${sort_keys} ${PARTITIONS} PARTITIONS )"`echo "\g"`
    fi

    sql ${TPC_DB} >> ${LOG_DIR}/Vector_Load.log <<EOF
${DDL_TO_RUN}
EOF

    # Build the load command. This is variable depending on:
    #   1. Whether sorting is required for large tables.
    #   2. HDFS is being used for the data source.
    if [ "${sort_keys}" == "" ]; then
        load_command="vwload -c -m -stats -z -t ${table_name} ${TPC_DB}"
    else
        load_command="vwload -c -m -t ${table_name}_stage ${TPC_DB}"
        optimize_tables="${optimize_tables}-r${table_name} "
    fi

    if [ "${HDFS_INUSE}" = true ]; then
        # Below is to expand hdfs will card list of files as shell can't do it
        load_files=`hdfs dfs -ls ${HDFS_URL}/${HDFS_DATA_DIR}/${table_name}_[1-9]*.dat | sed 's/  */ /g' | cut -d\  -f8`
        load_command=${load_command}" ${load_files}"
    else
        load_command=${load_command}" ${PWD}/${DATA_DIR}/${table_name}_[1-9]*.dat"
    fi

    # Populate the table from any available generated data (May not always be?)
    ${load_command} >> ${LOG_DIR}/Vector_Load.log

    # For sorted tables now create from the staging table then discard staging
    if [ "${sort_keys}" != "" ]; then
        echo "Creating from staging sorted table : ${table_name} (${sort_keys})"
        sql ${TPC_DB} >> ${LOG_DIR}/Vector_Load.log <<EOF
CREATE TABLE ${table_name} AS
SELECT
    *
FROM
    ${table_name}_stage
ORDER BY
    ${sort_keys}
WITH PARTITION = ( HASH ON ${sort_keys} ${PARTITIONS} PARTITIONS );
\g
DROP TABLE ${table_name}_stage
\g
COMMIT;
\g
EOF
    fi

done

# For sorted table now generate statistics this couldn't be done during the vwload 
# Currently generated for ALL columns 
if [ "${optimize_tables}" != "" ]; then
    echo "Optimising sorted tables"
    optimizedb ${TPC_DB} ${optimize_tables}
fi

# 7. Run the TPC SQL

echo ""
echo "Step 7 - Running the SQL Tests."
echo ""

${PWD}/TPC_DS_Run_Tests_Only.sh

echo ""
echo "TPC-DS Style Benchmark run completed successfully"
echo ""

#------------------------------------------------------------------------------#
#---------------------------- End of Shell Script -----------------------------#
#------------------------------------------------------------------------------#
