// Create a vendor
query "vendors" verb=POST {
  api_group = "ProcureFlow"
  auth = "user"

  input {
    text name filters=trim
    email contact_email? filters=trim|lower
    text contact_phone? filters=trim
    text address? filters=trim
    text tax_id? filters=trim
  }

  stack {
    db.add "pf_vendor" {
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
