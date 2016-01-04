CREATE TABLE household_demographics (
    hd_demo_sk bigint NOT NULL,
    hd_income_band_sk bigint,
    hd_buy_potential character(15),
    hd_dep_count integer,
    hd_vehicle_count integer
)
