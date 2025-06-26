# Task 12

Set up a GitHub Actions workflow to handle deployment:
- Push the pre-built Docker image to Amazon ECR, tagged with the GitHub commit SHA.
- Update the ECS Task Definition with the new image tag dynamically.
- Trigger an AWS CodeDeploy deployment to roll out the updated ECS service.
- Optionally, monitor deployment status and initiate rollback if the deployment fails.

---

## 1. Docker image and ECR
- we already have the image in docker hub `ayush2832/strapi3:v6`. 
- We created the ecs using `aws ecr create-repository --repository-name strapirepo`
> aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.<your-region>.amazonaws.com

aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 349769753356.dkr.ecr.us-east-2.amazonaws.com

> docker tag my-app:latest <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/<your-ecr-repo>:$SHA

docker tag my-app:latest 349769753356.dkr.ecr.us-east-2.amazonaws.com/strapirepo:$SHA

- Getting task definitoin arn
> aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query "services[0].taskDefinition" \
  --output text

aws ecs describe-services \
  --cluster strapi-cluster \
  --services strapi-service \
  --query "services[0].taskDefinition" \
  --output text

> Output: arn:aws:ecs:us-east-2:349769753356:task-definition/strapi-task:28

- Save task definion arn
> TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query "services[0].taskDefinition" \
  --output text)

TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster strapi-cluster  \
  --services strapi-service \
  --query "services[0].taskDefinition" \
  --output text)

> aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --query "taskDefinition" > task-def.json

aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --query "taskDefinition" > task-def.json

> export NEW_IMAGE="349769753356.dkr.ecr.us-east-2.amazonaws.com/strapirepo:c970d02

> jq --arg IMAGE "$NEW_IMAGE" \
  '.containerDefinitions[0].image = $IMAGE
   | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' \
  task-def.json > new-task-def.json

- New task definiton
> aws ecs register-task-definition \
  --cli-input-json file://new-task-def.json

- Now create appspec.yml file and then 
> aws deploy create-deployment \
  --application-name strapi-codedeploy-app \
  --deployment-group-name strapi-codedeploy-group \
  --revision file://appspec.json \
  --deployment-config-name CodeDeployDefault.ECSCanary10Percent5Minutes \
  --description "Deploy new revision of task definition"

aws deploy create-deployment \
  --application-name strapi-codedeploy-app \
  --deployment-group-name strapi-dg \
  --deployment-config-name CodeDeployDefault.ECSCanary10Percent5Minutes \
  --revision "$(jq -n --arg content "$(jq -c . appspec.json)" \
    '{revisionType: "AppSpecContent", appSpecContent: {content: $content}}')" \
  --description "Deploying new ECS task definition"

