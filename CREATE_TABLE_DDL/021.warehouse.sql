CREATE TABLE warehouse (
    w_warehouse_sk integer NOT NULL,
    w_warehouse_id character(16) NOT NULL,
    w_warehouse_name character varying(20),
    w_warehouse_sq_ft integer,
    w_street_number character(10),
    w_street_name character varying(60),
    w_street_type character(15),
    w_suite_number character(10),
    w_city character varying(60),
    w_county character varying(30),
    w_state character(2),
    w_zip character(10),
    w_country character varying(20),
    w_gmt_offset numeric(5,2)
)
