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
