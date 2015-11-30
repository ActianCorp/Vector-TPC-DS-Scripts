CREATE TABLE customer_demographics (
    cd_demo_sk integer NOT NULL,
    cd_gender character(1),
    cd_marital_status character(1),
    cd_education_status character(20),
    cd_purchase_estimate integer,
    cd_credit_rating character(10),
    cd_dep_count integer,
    cd_dep_employed_count integer,
    cd_dep_college_count integer
)
WITH PARTITION = (HASH ON #HASHKEYS# #PARTITIONS# PARTITIONS)
