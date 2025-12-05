# Nextwork — Web Project

This repository contains the Nextwork web application and demonstrates a production-ready CI/CD pipeline implemented with AWS developer tools: CodePipeline, CodeBuild, CodeDeploy, and CodeArtifact. The README below documents the architecture, configuration examples, and step-by-step guidance to reproduce the pipeline so you can demonstrate hands-on experience with AWS CI/CD for modern web apps.

<img width="1359" height="432" alt="architecture-complete" src="https://github.com/user-attachments/assets/b766c640-1a84-457b-9e97-4a735fa5927a" />

Table of contents
- Project overview
- Goals
- Architecture (high level)
- Components and responsibilities
- Prerequisites
- Example configuration files
  - buildspec.yml
  - appspec.yml (EC2/On-Prem / simple script-based deploy)
  - CodeBuild environment variables & npm/CodeArtifact auth
- Recommended IAM roles & minimum permissions
- Deploy targets (S3/CloudFront static + CodeDeploy for EC2/ECS)
- Infrastructure as code suggestions
- Observability, testing & rollback strategies
- Troubleshooting tips
- Next steps / roadmap
- Contributing / Author

Project overview
This repository holds the Nextwork web application. The CI/CD pipeline showcased here covers:
- Source -> Build -> Artifact publishing -> Deploy
- Builds powered by AWS CodeBuild
- Artifact repository managed by AWS CodeArtifact (private npm packages / dependencies)
- Orchestration and approvals using AWS CodePipeline
- Deployments using AWS CodeDeploy (EC2 / ECS / Lambda - this README includes examples for EC2/script-based deploy and notes for ECS)
- Secure auth and least-privilege IAM roles
- Automated post-deploy validation and rollback guidance

Goals
- Demonstrate a full CI/CD pipeline using AWS managed services (CodePipeline, CodeBuild, CodeDeploy, CodeArtifact)
- Show how to authenticate private package repositories (CodeArtifact) from CodeBuild
- Provide sample build/deploy configuration files (buildspec.yml, appspec.yml)
- Explain the minimum IAM permissions and environment variables required
- Provide guidance for infrastructure as code and production hardening

High-level architecture
- GitHub (or CodeCommit) as Source -> CodePipeline
- CodePipeline triggers CodeBuild to run the build and publish artifacts
- CodeBuild can publish build artifacts to an S3 bucket (artifact store) and optionally publish packages to CodeArtifact
- CodePipeline then invokes CodeDeploy to push the artifact to target hosts (EC2/ECS/Lambda) or an S3-backed static website + CloudFront for Next.js static export
- Monitoring with CloudWatch Logs and CodePipeline/CodeBuild consoles

Components & responsibilities
- CodePipeline: orchestrates source → build → deploy stages and optional manual approval
- CodeBuild: runs build steps (install, test, build, package) as specified in buildspec.yml
- CodeArtifact: private package registry for npm (or pip/maven), used to centralize internal packages and speed builds
- CodeDeploy: performs safe deployments, supports hooks (preStop, AfterInstall, ApplicationStart, ValidateService)
- S3: optional artifact store, hosting static build output, or staging for CodeDeploy
- CloudWatch: logs build/deploy activity and metrics for observability


Prerequisites (before creating the pipeline)
- AWS account with privileges to create CodePipeline, CodeBuild, CodeDeploy, CodeArtifact, IAM roles, S3, (EC2/ECS) resources
- S3 bucket to store pipeline artifacts
- CodeArtifact domain & repository (if using private packages)
- EC2 instances or ECS cluster with CodeDeploy agent (for EC2/ECS deployments) OR an S3 + CloudFront distribution for static hosting
- GitHub repository connected via a personal access token or GitHub App (or use CodeCommit)
- Node.js project (Next.js), package.json present in repository root

Example buildspec.yml
This buildspec demonstrates installing from CodeArtifact, running tests, building a Next.js project, and pushing artifacts into the pipeline artifact store.

```yaml
version: 0.2

env:
  variables:
    NODE_ENV: "production"
    # CODEARTIFACT env vars are injected by the pipeline or CodeBuild project
phases:
  install:
    runtime-versions:
      nodejs: 18
    commands:
      - echo "Installing AWS CLI v2 and jq (if not present)"
      - apt-get update -y || true
      - apt-get install -y jq || true
      - echo "Configuring npm to use CodeArtifact (if CODEARTIFACT_DOMAIN is set)"
      - |
        if [ -n "$CODEARTIFACT_DOMAIN" ]; then
          aws codeartifact login --tool npm --domain "$CODEARTIFACT_DOMAIN" --domain-owner "$CODEARTIFACT_DOMAIN_OWNER" --repository "$CODEARTIFACT_REPO" --region "$AWS_DEFAULT_REGION"
        fi
      - npm ci
  pre_build:
    commands:
      - echo "Running lint & tests"
      - npm run lint || true
      - npm test
  build:
    commands:
      - echo "Building Next.js app"
      - npm run build
      - npm run export # optional for static export
  post_build:
    commands:
      - echo "Preparing artifact:"
      - mkdir -p artifact
      - cp -r .next/ artifact/.next
      - cp -r public/ artifact/public
      - cp package.json artifact/
      - echo "Build finished at `date`"
artifacts:
  files:
    - artifact/**/*
  discard-paths: no
cache:
  paths:
    - node_modules/**/*
```

Notes:
- The aws codeartifact login step uses the AWS CLI to authenticate npm to CodeArtifact and writes an npm token in ~/.npmrc for the build session.
- Provide CodeArtifact environment variables via CodeBuild project or CodePipeline (CODEARTIFACT_DOMAIN, CODEARTIFACT_REPO, CODEARTIFACT_DOMAIN_OWNER, AWS_DEFAULT_REGION).

Example appspec.yml (EC2/script-based deploy)
Use this when deploying a packaged build to EC2 instances running the CodeDeploy agent.

```yaml
version: 0.0
os: linux
files:
  - source: /
    destination: /var/www/nextwork
hooks:
  BeforeInstall:
    - location: scripts/stop_app.sh
      timeout: 300
      runas: root
  AfterInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
      runas: root
  ApplicationStart:
    - location: scripts/start_app.sh
      timeout: 300
      runas: root
  ValidateService:
    - location: scripts/validate_deploy.sh
      timeout: 120
      runas: root
```

Example deployment hook scripts
- scripts/install_dependencies.sh:
  - Ensure Node.js is available, install production dependencies, migrate DB if needed.
- scripts/start_app.sh:
  - Use pm2/systemd to start the Node service or serve static files behind nginx.
- scripts/validate_deploy.sh:
  - Run smoke tests (cURL endpoints) and fail if health checks fail.

CodeArtifact integration & auth from CodeBuild
- Create a CodeArtifact domain and repository:
  - aws codeartifact create-domain --domain my-org
  - aws codeartifact create-repository --domain my-org --repository nextwork-repo
- From CodeBuild, authenticate npm with:
  - aws codeartifact login --tool npm --domain my-org --repository nextwork-repo --region us-east-1
- Alternatively, retrieve an authorization token and write ~/.npmrc:
  - TOKEN=$(aws codeartifact get-authorization-token --domain my-org --domain-owner 123456789012 --query authorizationToken --output text)
  - printf "//$(aws codeartifact get-repository-endpoint --domain my-org --domain-owner 123456789012 --repository nextwork-repo --format npm | sed 's#https://##')/:_authToken=%s\n" "$TOKEN" > ~/.npmrc

Minimum IAM roles & permissions (conceptual)
- CodePipeline role:
  - sts:AssumeRole by CodePipeline
  - Permissions to read from source (GitHub/CodeCommit), invoke CodeBuild, pass role to CodeBuild, access S3 artifact store, start CodeDeploy deployments
- CodeBuild role:
  - s3:GetObject/GetObjectVersion/PutObject on artifact bucket
  - codeartifact:GetAuthorizationToken, codeartifact:GetRepositoryEndpoint, codeartifact:ReadFromRepository
  - logs:CreateLogStream / PutLogEvents
  - ecr:GetAuthorizationToken / ecr:BatchGetImage (if using ECR)
  - kms:Decrypt (if using encrypted artifacts)
- CodeDeploy role:
  - iam:PassRole to instance profile
  - s3:GetObject for artifacts, codedeploy:CreateDeployment, codedeploy:RegisterApplicationRevision
- Instance profile for EC2 targets:
  - s3:GetObject to fetch the deployment artifact
  - Additional permissions for app runtime operations as required

Deploy targets and variations
- Static hosting (recommended for Next.js static export):
  - Build and npm run export -> upload output to S3 -> CloudFront invalidation as a CodeDeploy/CodePipeline step
- Dynamic SSR (Next.js server):
  - Deploy built .next folder to EC2 instances (or container image to ECS)
  - Use CodeDeploy to orchestrate rollbacks and lifecycle hooks
- ECS + CodeDeploy:
  - Use CodeBuild to build and push Docker images to ECR
  - Use CodeDeploy (with ECS deployment provider) to update the ECS service with a new task definition (blue/green or rolling)
- Lambda:
  - If using serverless functions, CodeDeploy supports Lambda alias-based deployments with traffic shifting

Infrastructure as code (recommended)
- Use CloudFormation or Terraform to:
  - Create CodePipeline with Source/Build/Deploy stages
  - Create CodeBuild projects (with buildspec or S3-stored buildspec)
  - Create CodeDeploy application and deployment groups
  - Create CodeArtifact domain & repository
  - Create IAM roles and policies
- Example approach:
  - A CloudFormation stack for pipeline orchestration and IAM roles
  - A separate stack for compute (EC2 Auto Scaling Group with CodeDeploy agent or ECS cluster + services)

Observability, testing & rollback
- Log everything to CloudWatch Logs (CodeBuild and CodeDeploy produce logs)
- Add a ValidateService hook in appspec.yml that runs health checks and fails the deployment when checks fail
- Use CodeDeploy deployment configuration (HalfAtATime, AllAtOnce version alternatives) and enable automatic rollback on failure
- Add SNS notifications for pipeline failures
- Consider Canary / Blue-Green deployment strategies for zero-downtime releases

Common troubleshooting tips
- Build failure: check CloudWatch Logs for CodeBuild; ensure env vars and CodeArtifact auth are present in build environment
- CodeArtifact auth issues: verify CODEARTIFACT_DOMAIN, CODEARTIFACT_DOMAIN_OWNER, CODEARTIFACT_REPO, and credentials (role permissions)
- CodeDeploy agent not installed: confirm agent is installed and running on EC2 targets (and the agent user has access to the instance profile)
- Permissions errors: validate IAM role trust relationships and that CodePipeline can pass roles for CodeBuild/CodeDeploy
- Artifact not found: confirm artifact names in pipeline stage configuration and S3 object keys

Security considerations
- Use least-privilege IAM policies and separate roles for pipeline services
- Store secrets (e.g., GitHub token, npm tokens) in AWS Secrets Manager or Parameter Store and reference them in CodeBuild as encrypted environment variables
- Protect CodeArtifact domain with resource policies and restrict domain owner and repository access
- Enable encryption at rest for S3 artifacts and use KMS keys where required

Cost considerations
- CodePipeline and CodeBuild have per-minute and per-pipeline costs; evaluate build concurrency and caching to reduce cost
- CodeArtifact has storage/requests costs; remove stale packages and enable retention policies

Examples & snippets to get started quickly
- Creating a CodeBuild project (CLI concept):
  - aws codebuild create-project --name nextwork-build --source type=GITHUB,location=https://github.com/ARJ2004/nextwork-web-project --artifacts type=S3,location=my-pipeline-artifacts-bucket --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:6.0,computeType=BUILD_GENERAL1_MEDIUM --service-role arn:aws:iam::123456789012:role/CodeBuildServiceRole
- Create a CodePipeline with stages: Source (GitHub) -> Build (CodeBuild) -> Deploy (CodeDeploy)

Repository structure suggestion
- /src                # application source
- package.json
- buildspec.yml       # recommended to keep at repo root and referenced by CodeBuild
- appspec.yml         # for CodeDeploy
- /scripts            # deployment hook scripts (start/stop/validate)
- README.md

What I created in this README
I documented a clear, reproducible pipeline pattern using CodePipeline, CodeBuild, CodeDeploy, and CodeArtifact. The README includes recommended buildspec and appspec examples, IAM and auth guidance, deployment options (static hosting, EC2, ECS), common troubleshooting, and next steps for production hardening.

What's next
- Add CloudFormation/Terraform templates to this repo to explicitly create the CodePipeline/CodeBuild/CodeDeploy/CodeArtifact resources (recommended)
- Add pipeline YAML/JSON in /infrastructure and a sample CodeBuild project definition that references the included buildspec.yml
- Add more comprehensive smoke tests and Canary/Blue-Green deploy examples for automated validation and safer rollouts
- Integrate monitoring/alerts (SNS + Slack) and automated rollback policies

Contributing
If you'd like to extend the pipeline examples (ECS blue/green, Terraform automation, multi-account cross-region deployment), open a PR or file an issue describing the enhancement.

Author
ARJ2004 — CI/CD pipeline examples and configuration for Nextwork

License
MIT
