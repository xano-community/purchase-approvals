// List purchase requests
query "requests" verb=GET {
  api_group = "ProcureFlow"
  auth = "user"

  input {
    text status? filters=trim|lower
    int vendor_id?
    int requester_id?
    int page?=1 filters=min:1
    int per_page?=20 filters=min:1|max:100
  }

  stack {
    db.query "pf_purchase_request" {
      where = $db.pf_purchase_request.status ==? $input.status && $db.pf_purchase_request.vendor_id ==? $input.vendor_id && $db.pf_purchase_request.requester_id ==? $input.requester_id
      sort = {created_at: "desc"}
      return = {
        type: "list",
        paging: {page: $input.page, per_page: $input.per_page, totals: true}
      }
    } as $requests
  }

  response = $requests
}
