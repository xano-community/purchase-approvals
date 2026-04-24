table "pf_request_line_item" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int request_id {
      table = "pf_purchase_request"
    }
    text description filters=trim
    int quantity?=1
    decimal unit_price?=0
    decimal line_total?=0
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "request_id"}]}
  ]
}
