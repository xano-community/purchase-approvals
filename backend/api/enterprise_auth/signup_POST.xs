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
