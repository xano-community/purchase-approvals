table "purchase_request" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    timestamp updated_at?
    text title filters=trim
    text justification?
    int requester_id {
      table = "user"
    }
    int vendor_id? {
      table = "vendor"
    }
    enum status?="draft" {
      values = ["draft", "submitted", "in_review", "approved", "rejected", "cancelled"]
    }
    decimal total_amount?=0
    text department?
    timestamp submitted_at?
    timestamp decided_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "status"}]}
    {type: "btree", field: [{name: "requester_id"}]}
    {type: "btree", field: [{name: "vendor_id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
  ]
}
