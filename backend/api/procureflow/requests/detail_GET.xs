// Get a purchase request with line items, approvals, vendor
query "requests/{request_id}" verb=GET {
  api_group = "ProcureFlow"
  auth = "user"

  input {
    int request_id
  }

  stack {
    db.get "pf_purchase_request" {
      field_name = "id"
      field_value = $input.request_id
    } as $request

    precondition ($request != null) {
      error_type = "notfound"
      error = "Purchase request not found"
    }

    db.get "user" {
      field_name = "id"
      field_value = $request.requester_id
      output = ["id", "name", "email"]
    } as $requester

    db.get "pf_vendor" {
      field_name = "id"
      field_value = $request.vendor_id
    } as $vendor

    db.query "pf_request_line_item" {
      where = $db.pf_request_line_item.request_id == $input.request_id
      sort = {id: "asc"}
    } as $line_items

    db.query "pf_approval_step" {
      where = $db.pf_approval_step.request_id == $input.request_id
      sort = {sequence: "asc"}
    } as $approval_steps

    var $approvals_enriched { value = [] }

    foreach ($approval_steps) {
      each as $step {
        db.get "user" {
          field_name = "id"
          field_value = $step.approver_id
          output = ["id", "name", "email"]
        } as $approver

        var.update $approvals_enriched {
          value = $approvals_enriched|push:($step|set:"approver":$approver)
        }
      }
    }

    var $result {
      value = $request|set:"requester":$requester|set:"vendor":$vendor|set:"line_items":$line_items|set:"approvals":$approvals_enriched
    }
  }

  response = $result
}
