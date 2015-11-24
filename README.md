This collection of scripts and files will Create, Load and Execute a single stream 'TPC-DS Style Benchmark'

PLEASE NOTE 

This is not intended to represent an official TPC benchmark. 

It does however correctly use dsdgen and dsqgen to generate the data and TPC DS benchmark SQL from the TPC templates. 
It is simply intended as a useful tool for Vector/VectorH performance evaluation.

Only minor modfications where required to the TPC Template SQL. This was in relation to SQL statements where number of days are added.
For these statements in Vector/VectorH quotes must be added but this in no way affects the itegrity of the SQL. e.g. 30 days --> '30 days'
Templates updated accordingly:
    5,12,16,20,21,32,37,40,77,80,82,92,94,95 and 98


This README effectively duplicates the documentation in the main script TPC_DS_Run.sh

Run as a Vector or VectorH 'actian' user with the environment set for Vector/VectorH e.g. source.ingVHsh. The user should have the appropriate sudo access to ensure essential packages can be installed.

To install and run:

    1. Install git e.g. yum -y install git 
    2. git clone -q --depth=1 https://github.com/ActianCorp/Vector-TPC-DS-Scripts
    3. cd Vector-TPC-DS-Scripts
    4. chmod 755 *.sh
    5. ./TPC_DS_Run.sh 'Data set size in GB'

The only parameter to TPC_DS_Run is the size of the data to be used in the test. 1 = 1Gb, 100 = 100Gb.  This value is used to calculate the total data set size.
    Data Set Size = No. of Nodes x THIS Parameter 
If this parameter is not passed the default is to generate 1Gb per node. For Vector the No. of Nodes is always 1.

The results of the TPC style tests can be found in ${LOGDIR} where this by is by default the directory 'LOG_FILES' directly below the install directory. Output in this directory includes:

    1. TPC_DS_Summary_Results.txt   - Summary of the run with run timings.
    2. TPC_DS_query'nn'_Results.out - The output from each benchmark SQL run.

This package has been tested against both Vector and VectorH. 

The script is fully re-runnable from the beginning. 
To clean up afterwards:

    1. rm -fR ~/TPC_DS*
    2. destroydb tpc_db

