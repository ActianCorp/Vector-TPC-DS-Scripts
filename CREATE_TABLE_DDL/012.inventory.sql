CREATE TABLE inventory (
    inv_date_sk integer NOT NULL,
    inv_item_sk integer NOT NULL,
    inv_warehouse_sk integer NOT NULL,
    inv_quantity_on_hand integer
)
WITH PARTITION = (HASH ON #HASHKEYS# #PARTITIONS# PARTITIONS)
