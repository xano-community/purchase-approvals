// Create a purchase request with line items and approval chain
query "requests" verb=POST {
  api_group = "ProcureFlow"
  auth = "user"

  input {
    text title filters=trim
    text justification? filters=trim
    int vendor_id?
    text department? filters=trim
    object[] line_items? {
      schema {
        text description
        int quantity
        decimal unit_price
      }
    }
    int[] approver_ids?
  }

  stack {
    var $total { value = 0 }

    conditional {
      if ($input.line_items != null) {
        foreach ($input.line_items) {
          each as $li {
            var.update $total {
              value = $total + ($li.quantity * $li.unit_price)
            }
          }
        }
      }
    }

    db.add "pf_purchase_request" {
      data = {
        title       : $input.title,
        justification: $input.justification,
        requester_id: $auth.id,
        vendor_id   : $input.vendor_id,
        department  : $input.department,
        status      : "draft",
        total_amount: $total
      }
    } as $request

    conditional {
      if ($input.line_items != null) {
        foreach ($input.line_items) {
          each as $li {
            db.add "pf_request_line_item" {
              data = {
                request_id : $request.id,
                description: $li.description,
                quantity   : $li.quantity,
                unit_price : $li.unit_price,
                line_total : $li.quantity * $li.unit_price
              }
            }
          }
        }
      }
    }

    conditional {
      if ($input.approver_ids != null) {
        var $seq { value = 1 }
        foreach ($input.approver_ids) {
          each as $approver_id {
            db.add "pf_approval_step" {
              data = {
                request_id : $request.id,
                approver_id: $approver_id,
                sequence   : $seq,
                status     : "pending"
              }
            }
            var.update $seq { value = $seq + 1 }
          }
        }
      }
    }
  }

  response = $request
}
