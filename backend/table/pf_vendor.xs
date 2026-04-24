table "pf_vendor" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    text name filters=trim
    email contact_email? filters=trim|lower
    text contact_phone?
    text address?
    text tax_id?
    enum status?="active" {
      values = ["active", "inactive", "pending_review"]
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "name"}]}
    {type: "btree", field: [{name: "status"}]}
  ]
}
