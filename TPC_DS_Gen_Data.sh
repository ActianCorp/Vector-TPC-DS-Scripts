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
#     $3 - The size of the data to be generated in Gigabytes e.g. 1 = 1Gb

#-------------------------------------------------------------------------------

set -e
PARALLEL=$1
CHILD=$2
GEN_DATA_SCALE=$3
DATA_DIR=DATA_GENERATED

for table in $(cat ${PWD}/build_data_for_tables.txt); do
	table_name=`echo ${table} | awk -F '|' '{print $1}'`

	${PWD}/dsdgen -table ${table_name} -scale ${GEN_DATA_SCALE} -dir ${PWD}/${DATA_DIR} -parallel ${PARALLEL} -child ${CHILD} -terminate n

done

echo "COMPLETE: dsdgen parallel ${PARALLEL} child ${CHILD} scale ${GEN_DATA_SCALE}"

#------------------------------------------------------------------------------#
#---------------------------- End of Shell Script -----------------------------#
#------------------------------------------------------------------------------#
