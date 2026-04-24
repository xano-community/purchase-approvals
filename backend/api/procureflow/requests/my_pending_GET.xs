// Requests pending the current user's approval
query "requests/my-pending" verb=GET {
  api_group = "ProcureFlow"
  auth = "user"

  input {}

  stack {
    db.query "pf_approval_step" {
      where = $db.pf_approval_step.approver_id == $auth.id && $db.pf_approval_step.status == "pending"
      sort = {created_at: "desc"}
    } as $pending_steps

    var $enriched { value = [] }

    foreach ($pending_steps) {
      each as $step {
        db.get "pf_purchase_request" {
          field_name = "id"
          field_value = $step.request_id
        } as $req

        conditional {
          if ($req != null && ($req.status == "submitted" || $req.status == "in_review")) {
            var.update $enriched {
              value = $enriched|push:($step|set:"request":$req)
            }
          }
        }
      }
    }
  }

  response = $enriched
}
