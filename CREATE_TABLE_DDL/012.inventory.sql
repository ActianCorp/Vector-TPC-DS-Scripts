CREATE TABLE inventory (
    inv_date_sk bigint NOT NULL,
    inv_item_sk bigint NOT NULL,
    inv_warehouse_sk bigint NOT NULL,
    inv_quantity_on_hand integer
)
