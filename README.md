This collection of scripts and files will Create, Load and Execute a single stream 'TPC-DS Style Benchmark'

It has been tested against Vector 4.2.2 (CentOS 6.7) and VectorH 4.2.1 (CentOS 6.4). 

PLEASE NOTE 

This is not intended to represent an official TPC benchmark. 

It does however correctly use dsdgen and dsqgen to generate the data and TPC DS benchmark SQL from the TPC templates. 
It is simply intended as a useful tool for Vector/VectorH performance evaluation.

Only minor modfications where required to the TPC Template SQL. This was in relation to SQL statements where number of days are added.
For these statements in Vector/VectorH quotes must be added but this in no way affects the itegrity of the SQL. e.g. 30 days --> '30 days'
Templates updated accordingly:
    5,12,16,20,21,32,37,40,77,80,82,92,94,95 and 98


This README effectively duplicates the documentation in the main script TPC_DS_Run.sh

The script can be run as any user provided it is registered as a Vector/VectorH user and has sudo access.  The environment should have been set for Vector/VectorH e.g. source.ingVHsh. The user should have the appropriate sudo access to ensure essential packages can be installed.

To install and run:

    1. Install git e.g. yum -y install git 
    2. git clone -q --depth=1 https://github.com/ActianCorp/Vector-TPC-DS-Scripts
    3. cd Vector-TPC-DS-Scripts
    4. chmod 755 *.sh
    5. ./TPC_DS_Run.sh 'Data set size in GB'

The are 2 parameters to TPC_DS_Run:

    1. $1 - Scale Factor. The size of the data to be used in the test. 1 = 1Gb, 100 = 100Gb.
            If this parameter is not passed the default is to generate 1Gb per node.
            For Vector the No. of Nodes is always 1.
    2. $2 - Data Generation Threads. The no. of threads to be used for data generation.
            Default = 4.
            TPC provide no recommendation as to optimum threads but a decent rule of thumb is CPUs * COREs / 2

The results of the TPC style tests can be found in ${LOGDIR} where this by is by default the directory 'LOG_FILES' directly below the install directory. Output in this directory includes:

    1. TPC_DS_Summary_Results.txt   - Summary of the run with run timings.
    2. TPC_DS_query'nn'_Results.out - The output from each benchmark SQL run.

The TPC tests can be run separately. This will allow peformance modifications to be made to the data
without the incurring the overhead of re-generating the data which can be time intensive. To run the test only:

    1. cd Vector-TPC-DS-Scripts
    2. ./TPC_DS_Run_Tests_Only.sh

The script is fully re-runnable from the beginning. To clean up afterwards:

    1. rm -fR ~/TPC_DS*
    2. destroydb tpc_db

NOTES:

For VectorH installations there is often limited none HDFS file space. As a result HDFS is utilised as this is usually plentiful and addtionally the vwload employed to load the generated data should perform better.
Be aware that when generating very large databases, dsdgen still generates the chunks of the large data files in parrallel so they co-exist in normal file space until they are copied to HDFS (It has not been possible to get dsdgen to create the data files directly in HDFS). As a result it will still be possible to exhaust normal file space.

For the generation of larger data sets it is recommended that the no. of threads variable $THREADS be increased from the default of 4 in script TPC_DS_Run.sh.

It is recommended that this be run against Vector or VectorH 4.2.2 or above. Specifically for VectorH patch 22101 or above should be applied.  
Known Problem - Query 14 can hang with earlier versions.

The larger tables listed below are first staged then sorted on the hash key before loading into the final table. The hash key (can be multiple attributes) can be changed by updating file 'sort_data_for_tables.txt'. 

    1. catalog_returns
    2. catalog_sales
    3. customer_demographics
    4. inventory
    5. store_returns
    6. store_sales
    7. web_sales

It may be neceessary when creating very large databases to make addtional tables partitioned. This requires an appropriate entry in the file above.

