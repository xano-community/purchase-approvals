// Approver decides on their approval step: approve or reject
query "requests/{request_id}/decide" verb=POST {
  api_group = "Procurement"
  auth = "user"

  input {
    int request_id
    text decision filters=trim|lower
    text notes? filters=trim
  }

  stack {
    precondition ($input.decision == "approve" || $input.decision == "reject") {
      error_type = "inputerror"
      error = "Decision must be 'approve' or 'reject'"
    }

    db.query "approval_step" {
      where = $db.approval_step.request_id == $input.request_id && $db.approval_step.approver_id == $auth.id && $db.approval_step.status == "pending"
      sort = {sequence: "asc"}
      return = {type: "single"}
    } as $my_step

    precondition ($my_step != null) {
      error_type = "accessdenied"
      error = "No pending approval found for this user on this request"
    }

    var $new_status { value = "approved" }
    conditional {
      if ($input.decision == "reject") {
        var.update $new_status { value = "rejected" }
      }
    }

    db.edit "approval_step" {
      field_name = "id"
      field_value = $my_step.id
      data = {
        status  : $new_status,
        notes   : $input.notes,
        acted_at: now
      }
    }

    conditional {
      if ($input.decision == "reject") {
        db.edit "purchase_request" {
          field_name = "id"
          field_value = $input.request_id
          data = {
            status     : "rejected",
            decided_at : now,
            updated_at : now
          }
        }
      }
      else {
        db.query "approval_step" {
          where = $db.approval_step.request_id == $input.request_id && $db.approval_step.status == "pending"
          return = {type: "count"}
        } as $remaining

        conditional {
          if ($remaining == 0) {
            db.edit "purchase_request" {
              field_name = "id"
              field_value = $input.request_id
              data = {
                status     : "approved",
                decided_at : now,
                updated_at : now
              }
            }
          }
          else {
            db.edit "purchase_request" {
              field_name = "id"
              field_value = $input.request_id
              data = {
                status    : "in_review",
                updated_at: now
              }
            }
          }
        }
      }
    }

    db.get "purchase_request" {
      field_name = "id"
      field_value = $input.request_id
    } as $final
  }

  response = $final
}
