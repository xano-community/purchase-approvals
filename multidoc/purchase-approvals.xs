workspace templates {
  acceptance = {ai_terms: false}
  preferences = {
    internal_docs    : false
    track_performance: true
    sql_names        : false
    sql_columns      : true
  }
}
---
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
---
table "purchase_line_item" {
  auth = false

  schema {
    int id
    timestamp created_at?=now
    int request_id {
      table = "purchase_request"
    }
    text description filters=trim
    int quantity?=1
    decimal unit_price?=0
    decimal line_total?=0
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "request_id"}]}
  ]
}
---
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
---
table user {
  auth = true

  schema {
    int id
    timestamp created_at?=now {
      visibility = "private"
    }
  
    text name filters=trim
    email? email filters=trim|lower
    password? password filters=min:8|minAlpha:1|minDigit:1 {
      visibility = "internal"
    }
  }

  index = [
    {type: "primary", field: [{name: "id"}]}
    {type: "btree", field: [{name: "created_at", op: "desc"}]}
    {type: "btree|unique", field: [{name: "email", op: "asc"}]}
  ]

}
---
table "vendor" {
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
---
api_group EnterpriseAuth {
  canonical = "enterprise-auth"
  description = "Shared authentication for HelpDesk Pro, AssetVault, and Purchase Approvals"
  tags = ["auth", "shared"]
}
---
// Login and retrieve an authentication token
query "login" verb=POST {
  api_group = "EnterpriseAuth"

  input {
    email email filters=trim|lower
    text password
  }

  stack {
    db.get "user" {
      field_name = "email"
      field_value = $input.email
      output = ["id", "created_at", "name", "email", "password"]
    } as $user

    precondition ($user != null) {
      error_type = "accessdenied"
      error = "Invalid credentials"
    }

    security.check_password {
      text_password = $input.password
      hash_password = $user.password
    } as $pass_result

    precondition ($pass_result) {
      error_type = "accessdenied"
      error = "Invalid credentials"
    }

    security.create_auth_token {
      table = "user"
      extras = {}
      expiration = 86400
      id = $user.id
    } as $authToken
  }

  response = {
    authToken: $authToken,
    user: {id: $user.id, name: $user.name, email: $user.email}
  }
}
---
// Get the currently authenticated user
query "me" verb=GET {
  api_group = "EnterpriseAuth"
  auth = "user"

  input {}

  stack {
    db.get "user" {
      field_name = "id"
      field_value = $auth.id
      output = ["id", "created_at", "name", "email"]
    } as $user
  }

  response = $user
}
---
// Create a new account and retrieve an authentication token
query "signup" verb=POST {
  api_group = "EnterpriseAuth"

  input {
    text name filters=trim
    email email filters=trim|lower
    text password
  }

  stack {
    db.get "user" {
      field_name = "email"
      field_value = $input.email
    } as $existing

    precondition ($existing == null) {
      error_type = "inputerror"
      error = "Email already registered"
    }

    db.add "user" {
      data = {
        name    : $input.name,
        email   : $input.email,
        password: $input.password
      }
    } as $user

    security.create_auth_token {
      table = "user"
      extras = {}
      expiration = 86400
      id = $user.id
    } as $authToken
  }

  response = {
    authToken: $authToken,
    user: {id: $user.id, name: $user.name, email: $user.email}
  }
}
---
// List users (for selector dropdowns across apps)
query "users" verb=GET {
  api_group = "EnterpriseAuth"
  auth = "user"

  input {}

  stack {
    db.query "user" {
      sort = {name: "asc"}
      return = {type: "list"}
    } as $users

    var $sanitized { value = [] }

    foreach ($users) {
      each as $u {
        var.update $sanitized {
          value = $sanitized|push:{id: $u.id, name: $u.name, email: $u.email}
        }
      }
    }
  }

  response = $sanitized
}
---
api_group Procurement {
  canonical = "purchase-approvals"
  description = "Purchase Approvals - Purchase requisition and approval workflow"
  tags = ["procurement", "finance", "approvals"]
}
---
// Create a purchase request with line items and approval chain
query "requests" verb=POST {
  api_group = "Procurement"
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

    db.add "purchase_request" {
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
            db.add "purchase_line_item" {
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
            db.add "approval_step" {
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
---
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
---
// Get a purchase request with line items, approvals, vendor
query "requests/{request_id}" verb=GET {
  api_group = "Procurement"
  auth = "user"

  input {
    int request_id
  }

  stack {
    db.get "purchase_request" {
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

    db.get "vendor" {
      field_name = "id"
      field_value = $request.vendor_id
    } as $vendor

    db.query "purchase_line_item" {
      where = $db.purchase_line_item.request_id == $input.request_id
      sort = {id: "asc"}
    } as $line_items

    db.query "approval_step" {
      where = $db.approval_step.request_id == $input.request_id
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
---
// List purchase requests
query "requests" verb=GET {
  api_group = "Procurement"
  auth = "user"

  input {
    text status? filters=trim|lower
    int vendor_id?
    int requester_id?
    int page?=1 filters=min:1
    int per_page?=20 filters=min:1|max:100
  }

  stack {
    db.query "purchase_request" {
      where = $db.purchase_request.status ==? $input.status && $db.purchase_request.vendor_id ==? $input.vendor_id && $db.purchase_request.requester_id ==? $input.requester_id
      sort = {created_at: "desc"}
      return = {
        type: "list",
        paging: {page: $input.page, per_page: $input.per_page, totals: true}
      }
    } as $requests
  }

  response = $requests
}
---
// Requests pending the current user's approval
query "requests/my-pending" verb=GET {
  api_group = "Procurement"
  auth = "user"

  input {}

  stack {
    db.query "approval_step" {
      where = $db.approval_step.approver_id == $auth.id && $db.approval_step.status == "pending"
      sort = {created_at: "desc"}
    } as $pending_steps

    var $enriched { value = [] }

    foreach ($pending_steps) {
      each as $step {
        db.get "purchase_request" {
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
---
// Submit a draft request for review
query "requests/{request_id}/submit" verb=POST {
  api_group = "Procurement"
  auth = "user"

  input {
    int request_id
  }

  stack {
    db.get "purchase_request" {
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

    db.edit "purchase_request" {
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
---
// Seed Purchase Approvals with demo vendors and purchase requests. Idempotent.
query "seed" verb=POST {
  api_group = "Procurement"

  input {}

  stack {
    db.query "purchase_request" {
      return = {type: "count"}
    } as $existing

    precondition ($existing == 0) {
      error_type = "inputerror"
      error = "Purchase Approvals data already seeded."
    }

    var $seed_users {
      value = [
        {name: "Alice Johnson",   email: "alice.johnson@acme.enterprise"},
        {name: "Bob Martinez",    email: "bob.martinez@acme.enterprise"},
        {name: "Carol Nguyen",    email: "carol.nguyen@acme.enterprise"},
        {name: "David Okonkwo",   email: "david.okonkwo@acme.enterprise"},
        {name: "Emma Patel",      email: "emma.patel@acme.enterprise"},
        {name: "Frank Rivera",    email: "frank.rivera@acme.enterprise"},
        {name: "Grace Sullivan",  email: "grace.sullivan@acme.enterprise"},
        {name: "Henry Tanaka",    email: "henry.tanaka@acme.enterprise"}
      ]
    }

    foreach ($seed_users) {
      each as $u {
        db.get "user" {
          field_name = "email"
          field_value = $u.email
        } as $existing_user

        conditional {
          if ($existing_user == null) {
            db.add "user" {
              data = {name: $u.name, email: $u.email, password: "DemoPass1"}
            }
          }
        }
      }
    }

    var $vendor_seeds {
      value = [
        {name: "Apple Business",         email: "biz@apple.com",          phone: "+1-800-854-3680", address: "1 Apple Park Way, Cupertino CA 95014", tax_id: "94-2404110"},
        {name: "Dell Technologies",      email: "sales@dell.com",         phone: "+1-800-456-3355", address: "1 Dell Way, Round Rock TX 78682",     tax_id: "74-2487834"},
        {name: "Lenovo Enterprise",      email: "enterprise@lenovo.com",  phone: "+1-855-253-6686", address: "8001 Development Dr, Morrisville NC",  tax_id: "06-1514380"},
        {name: "Office Depot Business",  email: "business@officedepot.com", phone: "+1-888-263-3423", address: "6600 N Military Trl, Boca Raton FL",  tax_id: "59-2663954"},
        {name: "Atlassian",              email: "sales@atlassian.com",    phone: "+61-2-9262-1443", address: "341 George St, Sydney NSW 2000",       tax_id: "AU-106-611-523"},
        {name: "AWS (Amazon Web Services)", email: "aws-billing@amazon.com", phone: "+1-206-266-4064", address: "410 Terry Ave N, Seattle WA",         tax_id: "91-1646860"},
        {name: "WeWork Real Estate",     email: "enterprise@wework.com",  phone: "+1-844-493-9675", address: "115 W 18th St, New York NY",           tax_id: "81-5231091"},
        {name: "Cisco Systems",          email: "govt@cisco.com",         phone: "+1-800-553-6387", address: "170 W Tasman Dr, San Jose CA",         tax_id: "77-0059951"}
      ]
    }

    var $vendors { value = [] }

    foreach ($vendor_seeds) {
      each as $v {
        db.get "vendor" {
          field_name = "name"
          field_value = $v.name
        } as $existing_v

        conditional {
          if ($existing_v == null) {
            db.add "vendor" {
              data = {
                name         : $v.name,
                contact_email: $v.email,
                contact_phone: $v.phone,
                address      : $v.address,
                tax_id       : $v.tax_id,
                status       : "active"
              }
            } as $new_v

            var.update $vendors { value = $vendors|push:$new_v }
          }
          else {
            var.update $vendors { value = $vendors|push:$existing_v }
          }
        }
      }
    }

    var $request_seeds {
      value = [
        {title: "Q2 Laptop Refresh - Engineering Team",     vendor: "Apple Business",         dept: "Engineering", status: "approved",  req: "alice.johnson@acme.enterprise",  approvers: ["bob.martinez@acme.enterprise",  "grace.sullivan@acme.enterprise"], items: [{description: "MacBook Pro 14\" M3",        qty: 5,   price: 2499.0}, {description: "AppleCare+ 3yr",          qty: 5,  price: 279.0}]},
        {title: "New Office Standing Desks",                vendor: "Office Depot Business",  dept: "Facilities",  status: "submitted", req: "carol.nguyen@acme.enterprise",   approvers: ["david.okonkwo@acme.enterprise", "grace.sullivan@acme.enterprise"], items: [{description: "Electric Standing Desk",    qty: 12,  price: 449.0}]},
        {title: "AWS Reserved Instances - Production",      vendor: "AWS (Amazon Web Services)", dept: "Engineering", status: "approved", req: "emma.patel@acme.enterprise",     approvers: ["alice.johnson@acme.enterprise", "grace.sullivan@acme.enterprise"], items: [{description: "m5.2xlarge 1yr RI",          qty: 8,   price: 2340.0}]},
        {title: "Jira + Confluence Renewal 150 Seats",      vendor: "Atlassian",              dept: "Engineering", status: "in_review", req: "bob.martinez@acme.enterprise",   approvers: ["alice.johnson@acme.enterprise", "grace.sullivan@acme.enterprise"], items: [{description: "Jira Software Cloud 150u",   qty: 1,   price: 13440.0}, {description: "Confluence Cloud 150u",   qty: 1,  price: 9720.0}]},
        {title: "NYC Office Expansion - 20 Seats",          vendor: "WeWork Real Estate",     dept: "Facilities",  status: "draft",     req: "henry.tanaka@acme.enterprise",   approvers: ["grace.sullivan@acme.enterprise"],                           items: [{description: "Dedicated Desk / month",    qty: 20,  price: 750.0}]},
        {title: "Switch Upgrade - Data Center East",        vendor: "Cisco Systems",          dept: "IT",          status: "approved",  req: "frank.rivera@acme.enterprise",   approvers: ["bob.martinez@acme.enterprise",  "grace.sullivan@acme.enterprise"], items: [{description: "Cisco Catalyst 9300-48P",   qty: 4,   price: 5999.0}]},
        {title: "Developer Workstation Refresh",            vendor: "Dell Technologies",      dept: "IT",          status: "rejected",  req: "david.okonkwo@acme.enterprise",  approvers: ["bob.martinez@acme.enterprise",  "grace.sullivan@acme.enterprise"], items: [{description: "Dell Precision 5680",       qty: 10,  price: 3299.0}]},
        {title: "Conference Room A/V Overhaul",             vendor: "Lenovo Enterprise",      dept: "Facilities",  status: "submitted", req: "alice.johnson@acme.enterprise",  approvers: ["grace.sullivan@acme.enterprise"],                           items: [{description: "Conference AIO Solution",   qty: 3,   price: 4799.0}]},
        {title: "Marketing Asia Event Travel",              vendor: "Office Depot Business",  dept: "Marketing",   status: "approved",  req: "carol.nguyen@acme.enterprise",   approvers: ["grace.sullivan@acme.enterprise"],                           items: [{description: "Event Booth Materials",     qty: 1,   price: 8500.0}]},
        {title: "Q3 Security Training Licenses",            vendor: "Atlassian",              dept: "Security",    status: "in_review", req: "emma.patel@acme.enterprise",     approvers: ["bob.martinez@acme.enterprise",  "grace.sullivan@acme.enterprise"], items: [{description: "Security Awareness LMS/user", qty: 450, price: 29.0}]}
      ]
    }

    var $count { value = 0 }

    foreach ($request_seeds) {
      each as $r {
        db.get "user" {
          field_name = "email"
          field_value = $r.req
        } as $requester

        db.get "vendor" {
          field_name = "name"
          field_value = $r.vendor
        } as $vendor

        var $total { value = 0 }
        foreach ($r.items) {
          each as $it {
            var.update $total { value = $total + ($it.qty * $it.price) }
          }
        }

        var $submitted_ts { value = null }
        var $decided_ts   { value = null }

        conditional {
          if ($r.status != "draft") {
            var.update $submitted_ts { value = now }
          }
        }
        conditional {
          if ($r.status == "approved" || $r.status == "rejected") {
            var.update $decided_ts { value = now }
          }
        }

        db.add "purchase_request" {
          data = {
            title       : $r.title,
            justification: ("Standard " ~ $r.dept ~ " operating expense. See attached for vendor quote."),
            requester_id: $requester.id,
            vendor_id   : $vendor.id,
            department  : $r.dept,
            status      : $r.status,
            total_amount: $total,
            submitted_at: $submitted_ts,
            decided_at  : $decided_ts
          }
        } as $request

        foreach ($r.items) {
          each as $it {
            db.add "purchase_line_item" {
              data = {
                request_id : $request.id,
                description: $it.description,
                quantity   : $it.qty,
                unit_price : $it.price,
                line_total : $it.qty * $it.price
              }
            }
          }
        }

        var $seq { value = 1 }
        foreach ($r.approvers) {
          each as $approver_email {
            db.get "user" {
              field_name = "email"
              field_value = $approver_email
            } as $approver

            var $step_status { value = "pending" }
            var $acted { value = null }
            conditional {
              if ($r.status == "approved") {
                var.update $step_status { value = "approved" }
                var.update $acted { value = now }
              }
            }
            conditional {
              if ($r.status == "rejected" && $seq == 1) {
                var.update $step_status { value = "rejected" }
                var.update $acted { value = now }
              }
            }

            db.add "approval_step" {
              data = {
                request_id : $request.id,
                approver_id: $approver.id,
                sequence   : $seq,
                status     : $step_status,
                acted_at   : $acted
              }
            }

            var.update $seq { value = $seq + 1 }
          }
        }

        var.update $count { value = $count + 1 }
      }
    }
  }

  response = {success: true, requests_seeded: $count}
}
---
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
---
// Create a vendor
query "vendors" verb=POST {
  api_group = "Procurement"
  auth = "user"

  input {
    text name filters=trim
    email contact_email? filters=trim|lower
    text contact_phone? filters=trim
    text address? filters=trim
    text tax_id? filters=trim
  }

  stack {
    db.add "vendor" {
      data = {
        name         : $input.name,
        contact_email: $input.contact_email,
        contact_phone: $input.contact_phone,
        address      : $input.address,
        tax_id       : $input.tax_id,
        status       : "active"
      }
    } as $vendor
  }

  response = $vendor
}
---
// List vendors
query "vendors" verb=GET {
  api_group = "Procurement"
  auth = "user"

  input {
    text status? filters=trim|lower
    text q? filters=trim
    int page?=1 filters=min:1
    int per_page?=20 filters=min:1|max:100
  }

  stack {
    db.query "vendor" {
      where = $db.vendor.status ==? $input.status && $db.vendor.name includes? $input.q
      sort = {name: "asc"}
      return = {
        type: "list",
        paging: {page: $input.page, per_page: $input.per_page, totals: true}
      }
    } as $vendors
  }

  response = $vendors
}
