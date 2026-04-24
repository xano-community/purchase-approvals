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
