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
