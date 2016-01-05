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

# This script generates data for the tables listed in 'build_data_for_tables.txt'
# using a specified no. of threads to increase throughput.

# Parameters
#     $1 - No. of parallel threads to use creating the data
#     $2 - Child thread no. 
#     $3 - Scale Factor - The size of the data to be generated in Gigabytes 
#          e.g. 1 = 1Gb

#-------------------------------------------------------------------------------

set -e
PARALLEL=$1
CHILD=$2
SCALE_FACTOR=$3

for table in $(cat ${PWD}/build_data_for_tables.txt); do

	table_name=`echo ${table} | awk -F '|' '{print $1}'`

	${PWD}/dsdgen -table ${table_name} -scale ${SCALE_FACTOR} -dir ${DATA_DIR} -parallel ${PARALLEL} -child ${CHILD} -terminate n

    # Move each file produced to HDFS if available
    # (For vectorH on Hadoop 'normal' file space will be limited)
    #   - Leave any 'customer' files as they need a character set fix and can't do it in HDFS.
    #     These files will be fixed and moved to HDFS later.

    if [ -f ${DATA_DIR}/${table_name}_${CHILD}_${PARALLEL}.dat ];then

        if [ "${HDFS_INUSE}" = true -a "${table_name}" != "customer" ]; then

            hdfs dfs -put ${DATA_DIR}/${table_name}_${CHILD}_${PARALLEL}.dat ${HDFS_URL}/${HDFS_DATA_DIR}/.
            rm -f ${DATA_DIR}/${table_name}_${CHILD}_${PARALLEL}.dat 

            # dsdgen is not called explictly to create returns. These are created alongside
            # the sales. Hence, unavoidable hard coding here to copy to HDFS.
            # This relates to catalog_returns, store_returns and web_returns.

            if [ "${table_name}" == "catalog_sales" -o "${table_name}" == "store_sales" -o "${table_name}" == "web_sales" ]; then

                table_name_ret=`echo ${table_name} | sed 's/sales/returns/'`
                hdfs dfs -put ${DATA_DIR}/${table_name_ret}_${CHILD}_${PARALLEL}.dat ${HDFS_URL}/${HDFS_DATA_DIR}/.
                rm -f ${DATA_DIR}/${table_name_ret}_${CHILD}_${PARALLEL}.dat 

            fi
        fi
    fi

done

echo "COMPLETE: dsdgen parallel ${PARALLEL} child ${CHILD} scale ${SCALE_FACTOR}"

#------------------------------------------------------------------------------#
#---------------------------- End of Shell Script -----------------------------#
#------------------------------------------------------------------------------#
