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
