# Task 12

Set up a GitHub Actions workflow to handle deployment:
- Push the pre-built Docker image to Amazon ECR, tagged with the GitHub commit SHA.
- Update the ECS Task Definition with the new image tag dynamically.
- Trigger an AWS CodeDeploy deployment to roll out the updated ECS service.
- Optionally, monitor deployment status and initiate rollback if the deployment fails.

---

## 1. Manual Approach
[Docs I follow for aws cli commands](https://docs.aws.amazon.com/cli/latest/reference/ecs/describe-tasks.html)
[Docs I follow for github actions](http://github.com/aws-actions/amazon-ecs-deploy-task-definition?tab=readme-ov-file)

- we already have the image in docker hub `ayush2832/strapi3:v6`. 
- We created the ECR using `aws ecr create-repository --repository-name strapirepo`
> aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.<your-region>.amazonaws.com

- Then we give the tag to our image and push the image to the ECR 
> docker tag my-app:latest <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/<your-ecr-repo>:$SHA


- First we will get information about the ecs services running in the cluster. Because here we need to know which task definition and revision our ECS service is currently using.
> aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query "services[0].taskDefinition" \
  --output text

> Output: arn:aws:ecs:us-east-2:349769753356:task-definition/strapi-task:28
> little changes here
- Save task definion arn
> TASK_DEF_ARN=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query "services[0].taskDefinition" \
  --output text)

- Use TASK_DEF_ARN to get full information about the task definition.
> aws ecs describe-task-definition \
  --task-definition $TASK_DEF_ARN \
  --query "taskDefinition" > task-def.json

- Now we export the url the of the new image which we pulled in the ecr.
> export NEW_IMAGE="349769753356.dkr.ecr.us-east-2.amazonaws.com/strapirepo:c970d02

- Now we update the image in the task definiton and save it on new file.
> jq --arg IMAGE "$NEW_IMAGE" \
  '.containerDefinitions[0].image = $IMAGE
   | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' \
  task-def.json > new-task-def.json

- New task definiton
> aws ecs register-task-definition \
  --cli-input-json file://new-task-def.json

- Now create appspec.yml file which will simply tell do these thing in the container.
> aws deploy create-deployment \
  --application-name strapi-codedeploy-app \
  --deployment-group-name strapi-codedeploy-group \
  --revision file://appspec.json \
  --deployment-config-name CodeDeployDefault.ECSCanary10Percent5Minutes \
  --description "Deploy new revision of task definition"

- Then we create new deployment.
> aws deploy create-deployment \
  --application-name strapi-codedeploy-app \
  --deployment-group-name strapi-dg \
  --revision revisionType=AppSpecContent,appSpecContent="{content=\"$(cat appspec.yml)\"}" \
  --deployment-config-name CodeDeployDefault.ECSCanary10Percent5Minutes

## 2. Automation with github actions
- We can automate the above steps using the github actions.
- We define the basic things like run pipeline whenever
```yml
name: ECS automated deployment

on:
  push:
    branches: developer

jobs:
  deploy:
    runs-on: ubuntu-latest
```
- Then we login into the aws using the credentials and also fetch the code
```yml
    steps:

    - name: checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-2
```

- Then we login into our ECR
```yml
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
```
- Then we build our iameg and push into the ecr repository.
```yml
    - name: Build, tag, and push image to Amazon ECR
      id: build-image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        ECR_REPOSITORY: strapirepo
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ./strapi10
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
```

- Now we will download the task definition from the task that currenty used by the service.
```yml
    - name: Download task definition
      run: |
        aws ecs describe-task-definition --task-definition strapi-task --query taskDefinition > task-definition.json
```

- Now update the new image that is pushed by the github actions.
```yml
    - name: Fill in the new image ID in the Amazon ECS task definition
      id: task-def
      uses: aws-actions/amazon-ecs-render-task-definition@v1
      with:
        task-definition: task-definition.json
        container-name: strapi
        image: ${{ steps.build-image.outputs.image }}
```
- Here we have to delete the unecessary parameters from the task definitionn which we dont need
```yml
    - name: Clean up task definition JSON for registration
      run: |
       jq 'del(
       .taskDefinitionArn,
       .revision,
       .status,
       .requiresAttributes,
       .compatibilities,
       .registeredAt,
       .registeredBy
       )' task-definition.json > new-task-definition.json
```

- Then finally we need to update task definiotn and create new service with new revision
```yml
    - name: Update ECS Task Definition 
      run: |
           aws ecs register-task-definition \
           --cli-input-json file://new-task-definition.json


    - name : Cdde deploy
      run: |
        aws deploy create-deployment \
            --application-name strapi-codedeploy-app \
            --deployment-group-name strapi-dg \
            --revision revisionType=AppSpecContent,appSpecContent="{content=\"$(cat appspec.yml)\"}" \
            --deployment-config-name CodeDeployDefault.ECSCanary10Percent5Minutes
```
