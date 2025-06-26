# Task 12

## 1. Docker image and ECR
- we already have the image in docker hub `ayush2832/strapi3:v6`. 
- We created the ecs using `aws ecr create-repository --repository-name strapirepo`
> aws ecr get-login-password --region <your-region> | docker login --username AWS --password-stdin <your-account-id>.dkr.ecr.<your-region>.amazonaws.com

aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 349769753356.dkr.ecr.us-east-2.amazonaws.com

> docker tag my-app:latest <your-account-id>.dkr.ecr.<your-region>.amazonaws.com/<your-ecr-repo>:$SHA

docker tag my-app:latest 349769753356.dkr.ecr.us-east-2.amazonaws.com/strapirepo:$SHA
