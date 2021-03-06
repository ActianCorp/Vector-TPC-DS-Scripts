CREATE TABLE store_returns (
    sr_returned_date_sk bigint,
    sr_return_time_sk bigint,
    sr_item_sk bigint NOT NULL,
    sr_customer_sk bigint,
    sr_cdemo_sk bigint,
    sr_hdemo_sk bigint,
    sr_addr_sk bigint,
    sr_store_sk bigint,
    sr_reason_sk bigint,
    sr_ticket_number bigint NOT NULL,
    sr_return_quantity integer,
    sr_return_amt numeric(7,2),
    sr_return_tax numeric(7,2),
    sr_return_amt_inc_tax numeric(7,2),
    sr_fee numeric(7,2),
    sr_return_ship_cost numeric(7,2),
    sr_refunded_cash numeric(7,2),
    sr_reversed_charge numeric(7,2),
    sr_store_credit numeric(7,2),
    sr_net_loss numeric(7,2)
)
