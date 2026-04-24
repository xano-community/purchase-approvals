// Dashboard for purchasing: counts and spend
query "stats/dashboard" verb=GET {
  api_group = "Procurement"
  auth = "user"

  input {}

  stack {
    db.query "purchase_request" {
      where = $db.purchase_request.status == "draft"
      return = {type: "count"}
    } as $draft_count

    db.query "purchase_request" {
      where = $db.purchase_request.status == "submitted"
      return = {type: "count"}
    } as $submitted_count

    db.query "purchase_request" {
      where = $db.purchase_request.status == "in_review"
      return = {type: "count"}
    } as $in_review_count

    db.query "purchase_request" {
      where = $db.purchase_request.status == "approved"
      return = {type: "count"}
    } as $approved_count

    db.query "purchase_request" {
      where = $db.purchase_request.status == "rejected"
      return = {type: "count"}
    } as $rejected_count

    db.query "purchase_request" {
      where = $db.purchase_request.status == "approved"
    } as $approved_requests

    var $approved_spend { value = 0 }

    foreach ($approved_requests) {
      each as $r {
        var.update $approved_spend {
          value = $approved_spend + $r.total_amount
        }
      }
    }
  }

  response = {
    drafts: $draft_count,
    submitted: $submitted_count,
    in_review: $in_review_count,
    approved: $approved_count,
    rejected: $rejected_count,
    approved_spend: $approved_spend
  }
}
