resource "aws_codedeploy_app" "ecs_app" {
  name = "my-cd-app"
  compute_platform = "ECS"
}