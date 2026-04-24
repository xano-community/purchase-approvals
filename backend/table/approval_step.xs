table "approval_step" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int request_id {
      table = "purchase_request"
    }
    int approver_id {
      table = "user"
    }
    int sequence?=1
    enum status?="pending" {
      values = ["pending", "approved", "rejected", "skipped"]
    }
    text notes?
    timestamp acted_at?
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "request_id"}]}
    {type: "btree", field: [{name: "approver_id"}]}
    {type: "btree", field: [{name: "status"}]}
  ]
}
