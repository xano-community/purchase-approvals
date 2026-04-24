// Submit a draft request for review
query "requests/{request_id}/submit" verb=POST {
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
      error = "Request not found"
    }

    precondition ($request.status == "draft") {
      error_type = "inputerror"
      error = "Only draft requests can be submitted"
    }

    db.edit "pf_purchase_request" {
      field_name = "id"
      field_value = $input.request_id
      data = {
        status      : "submitted",
        submitted_at: now,
        updated_at  : now
      }
    } as $updated
  }

  response = $updated
}
