# ---- OUTPUT ----
output "website_url" {
  value = "https://${aws_cloudfront_distribution.site.domain_name}"
}

# The role ARN is needed in GitHub Actions to assume the role and get permissions to deploy.
output "role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}