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
