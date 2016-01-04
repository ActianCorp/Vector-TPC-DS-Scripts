CREATE TABLE catalog_page (
    cp_catalog_page_sk bigint NOT NULL,
    cp_catalog_page_id character(16) NOT NULL,
    cp_start_date_sk bigint,
    cp_end_date_sk bigint,
    cp_department character varying(50),
    cp_catalog_number integer,
    cp_catalog_page_number integer,
    cp_description character varying(100),
    cp_type character varying(100)
)
