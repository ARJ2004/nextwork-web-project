# Nextwork — Web Project

This repository contains the Nextwork Java web application and demonstrates a production-ready CI/CD pipeline implemented with AWS developer tools: CodePipeline, CodeBuild, CodeDeploy, and CodeArtifact. The README below documents the architecture, configuration examples, and step-by-step guidance to reproduce the pipeline so you can demonstrate hands-on experience with AWS CI/CD for Java web applications.

<img width="1359" height="432" alt="architecture-complete" src="https://github.com/user-attachments/assets/b766c640-1a84-457b-9e97-4a735fa5927a" />

Table of contents
- Project overview
- Goals
- Architecture (high level)
- Components and responsibilities
- Prerequisites
- Infrastructure as Code (CloudFormation)
- Example configuration files
  - buildspec.yml (Maven/Java build)
  - appspec.yml (CodeDeploy for Tomcat on EC2)
  - CodeBuild environment variables & CodeArtifact auth
- Recommended IAM roles & minimum permissions
- Deploy targets (EC2 with Tomcat and Apache)
- Observability, testing & rollback strategies
- Troubleshooting tips
- Next steps / roadmap
- Contributing / Author

Project overview
This repository holds the Nextwork Java web application. The CI/CD pipeline showcased here covers:
- Source -> Build -> Artifact publishing -> Deploy
- Builds powered by AWS CodeBuild with Maven
- Artifact repository managed by AWS CodeArtifact (private Maven packages / dependencies)
- Orchestration and approvals using AWS CodePipeline
- Deployments using AWS CodeDeploy to EC2 instances running Tomcat
- Infrastructure provisioned using CloudFormation (nextworkwebapp.yaml)
- Secure auth and least-privilege IAM roles
- Automated post-deploy validation and rollback guidance

Goals
- Demonstrate a full CI/CD pipeline using AWS managed services (CodePipeline, CodeBuild, CodeDeploy, CodeArtifact)
- Show how to authenticate private Maven repositories (CodeArtifact) from CodeBuild
- Provide sample build/deploy configuration files (buildspec.yml, appspec.yml)
- Demonstrate infrastructure provisioning using CloudFormation
- Explain the minimum IAM permissions and environment variables required
- Show deployment to EC2 with Tomcat and Apache HTTP server as reverse proxy

High-level architecture
- GitHub (or CodeCommit) as Source -> CodePipeline
- CodePipeline triggers CodeBuild to run Maven build and publish artifacts
- CodeBuild authenticates with CodeArtifact for Maven dependencies and publishes artifacts to S3
- CodePipeline then invokes CodeDeploy to deploy the WAR file to EC2 instances running Tomcat
- Apache HTTP server acts as reverse proxy for the Tomcat application
- Infrastructure provisioned using CloudFormation template (nextworkwebapp.yaml)
- Monitoring with CloudWatch Logs and CodePipeline/CodeBuild consoles

Components & responsibilities
- CodePipeline: orchestrates source → build → deploy stages and optional manual approval
- CodeBuild: runs Maven build steps (install, test, package) as specified in buildspec.yml
- CodeArtifact: private Maven repository for dependencies, used to centralize internal packages and speed builds
- CodeDeploy: performs safe deployments to EC2, supports hooks (BeforeInstall, ApplicationStart, ApplicationStop, ValidateService)
- EC2: hosts the web application with Tomcat application server and Apache HTTP server
- S3: artifact store for CodePipeline and deployment packages
- CloudWatch: logs build/deploy activity and metrics for observability


Prerequisites (before creating the pipeline)
- AWS account with privileges to create CodePipeline, CodeBuild, CodeDeploy, CodeArtifact, IAM roles, S3, EC2, VPC resources
- S3 bucket to store pipeline artifacts
- CodeArtifact domain & repository configured for Maven
- EC2 instances with CodeDeploy agent installed (provisioned via CloudFormation template)
- GitHub repository connected via a personal access token or GitHub App (or use CodeCommit)
- Java project with Maven, pom.xml present in repository root
- CloudFormation template (nextworkwebapp.yaml) for infrastructure provisioning

Infrastructure as Code (CloudFormation)
The repository includes `nextworkwebapp.yaml`, a CloudFormation template that provisions the complete infrastructure for the web application:

**Network Components:**
- VPC with CIDR block 10.11.0.0/16
- Public Subnet (10.11.0.0/20) in the first availability zone
- Internet Gateway for internet connectivity
- Route Table with route to Internet Gateway
- Security Group allowing HTTP access (port 80) from specified IP address

**Compute and IAM:**
- EC2 Instance (t2.micro) running Amazon Linux 2
- IAM Role (ServerRole) with AmazonSSMManagedInstanceCore and AmazonS3ReadOnlyAccess policies
- Instance Profile (DeployRoleProfile) for EC2 instance

**Parameters:**
- `AmazonLinuxAMIID`: Automatically retrieves the latest Amazon Linux 2 AMI
- `MyIP`: Your IP address (x.x.x.x/32) for restricting HTTP access

**Outputs:**
- Public IP URL for accessing the deployed web application

**Deployment:**
```bash
aws cloudformation create-stack \
  --stack-name nextwork-web-stack \
  --template-body file://nextworkwebapp.yaml \
  --parameters ParameterKey=MyIP,ParameterValue=YOUR_IP/32 \
  --capabilities CAPABILITY_IAM \
  --region YOUR_REGION
```

The infrastructure creates a secure, production-ready environment with proper network isolation, IAM roles, and security group rules for hosting the Java web application.

Example buildspec.yml (Maven/Java build)
This buildspec demonstrates authenticating with CodeArtifact, running a Maven build, and packaging the WAR file for deployment.

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      java: corretto8
  pre_build:
    commands:
      - echo Logging in to AWS CodeArtifact...
      - CODEARTIFACT_AUTH_TOKEN=`aws codeartifact get-authorization-token --domain nextwork --domain-owner 622488711156 --region ap-south-1 --query authorizationToken --output text`
      - export CODEARTIFACT_AUTH_TOKEN
  build:
    commands:
      - echo Build started on `date`
      - mvn clean install -s settings.xml
  post_build:
    commands:
      - echo Build completed on `date`
      - echo Packaging artifacts...
      - mvn package -s settings.xml
artifacts:
  files:
    - target/nextwork-web-project.war
    - appspec.yml
    - scripts/**/*
  discard-paths: no
```

Notes:
- Uses Amazon Corretto 8 (Java 8) as the runtime
- The `aws codeartifact get-authorization-token` command authenticates Maven with CodeArtifact
- Uses a custom `settings.xml` file that references CodeArtifact repository
- Packages the application as a WAR file for Tomcat deployment
- Includes deployment scripts and appspec.yml in the artifact bundle

Example appspec.yml (CodeDeploy for Tomcat on EC2)
Use this when deploying the packaged WAR file to EC2 instances running Tomcat with CodeDeploy agent.

```yaml
version: 0.0
os: linux
files:
  - source: /target/nextwork-web-project.war
    destination: /usr/share/tomcat/webapps/
hooks:
  BeforeInstall:
    - location: scripts/install_dependencies.sh
      timeout: 300
      runas: root
  ApplicationStart:
    - location: scripts/start_server.sh
      timeout: 300
      runas: root
  ApplicationStop:
    - location: scripts/stop_server.sh
      timeout: 300
      runas: root
```

Example deployment hook scripts
- **scripts/install_dependencies.sh**:
  - Installs Tomcat and Apache HTTP server
  - Configures Apache as a reverse proxy to Tomcat (port 80 -> 8080)
  - Sets up virtual host configuration for the application
- **scripts/start_server.sh**:
  - Starts Tomcat service
  - Starts Apache HTTP server service
  - Enables both services to start on boot
- **scripts/stop_server.sh**:
  - Gracefully stops Apache HTTP server if running
  - Gracefully stops Tomcat service if running
  - Ensures clean shutdown before new deployment

CodeArtifact integration & auth from CodeBuild
- Create a CodeArtifact domain and repository for Maven:
  - `aws codeartifact create-domain --domain nextwork`
  - `aws codeartifact create-repository --domain nextwork --repository nextwork-repo`
- From CodeBuild, authenticate Maven with:
  - `aws codeartifact get-authorization-token --domain nextwork --domain-owner ACCOUNT_ID --region REGION --query authorizationToken --output text`
  - Export the token as `CODEARTIFACT_AUTH_TOKEN` environment variable
- Configure `settings.xml` to use CodeArtifact repository endpoint with the authentication token
- The token is valid for 12 hours and is automatically used by Maven during the build process

Minimum IAM roles & permissions (conceptual)
- CodePipeline role:
  - sts:AssumeRole by CodePipeline
  - Permissions to read from source (GitHub/CodeCommit), invoke CodeBuild, pass role to CodeBuild, access S3 artifact store, start CodeDeploy deployments
- CodeBuild role:
  - s3:GetObject/GetObjectVersion/PutObject on artifact bucket
  - codeartifact:GetAuthorizationToken, codeartifact:GetRepositoryEndpoint, codeartifact:ReadFromRepository
  - logs:CreateLogStream / PutLogEvents
  - kms:Decrypt (if using encrypted artifacts)
- CodeDeploy role:
  - iam:PassRole to instance profile
  - s3:GetObject for artifacts, codedeploy:CreateDeployment, codedeploy:RegisterApplicationRevision
  - ec2:DescribeInstances, autoscaling:CompleteLifecycleAction (for EC2/ASG deployments)
- Instance profile for EC2 targets (ServerRole in CloudFormation):
  - s3:GetObject to fetch the deployment artifact (AmazonS3ReadOnlyAccess)
  - ssm:* for Systems Manager access (AmazonSSMManagedInstanceCore)
  - Additional permissions for app runtime operations as required

Deploy targets and variations
- **EC2 with Tomcat (implemented in this project)**:
  - Build WAR file with Maven and deploy to Tomcat on EC2
  - Apache HTTP server acts as reverse proxy (port 80 -> 8080)
  - Use CodeDeploy to orchestrate deployments with lifecycle hooks
  - Infrastructure provisioned via CloudFormation template
- **Auto Scaling Group with CodeDeploy**:
  - Deploy to multiple EC2 instances behind a load balancer
  - Use CodeDeploy deployment configurations (OneAtATime, HalfAtATime, AllAtOnce)
  - Enable automatic rollback on deployment failure
- **ECS with Docker containers**:
  - Package application as Docker image and push to ECR
  - Use CodeDeploy (with ECS deployment provider) for blue/green deployments
  - Update ECS service with new task definition
- **Elastic Beanstalk**:
  - Deploy WAR file directly to Elastic Beanstalk Java environment
  - Simplified management with automatic scaling and load balancing

Infrastructure as code (recommended)
This project includes a CloudFormation template (`nextworkwebapp.yaml`) that provisions:
- VPC with public subnet and internet gateway
- Security group with controlled HTTP access
- EC2 instance with proper IAM roles
- Instance profile for accessing AWS services

Additional CloudFormation/Terraform resources to create:
- CodePipeline with Source/Build/Deploy stages
- CodeBuild projects with buildspec.yml reference
- CodeDeploy application and deployment groups
- CodeArtifact domain & repository for Maven
- IAM roles and policies for pipeline services
- S3 bucket for pipeline artifacts

Example approach:
- Use the included `nextworkwebapp.yaml` for compute infrastructure
- Create a separate stack for pipeline orchestration (CodePipeline, CodeBuild, CodeDeploy)
- Create a stack for CodeArtifact domain and repository
- Use stack exports/imports to share resources between stacks

Observability, testing & rollback
- Log everything to CloudWatch Logs (CodeBuild and CodeDeploy produce logs)
- Add lifecycle hooks in appspec.yml to validate service health
- Monitor Tomcat and Apache logs on EC2 instances
- Use CodeDeploy deployment configuration (OneAtATime, HalfAtATime, AllAtOnce) and enable automatic rollback on failure
- Add SNS notifications for pipeline failures
- Consider Blue-Green deployment strategies for zero-downtime releases
- Use CloudWatch Alarms for application metrics (CPU, memory, HTTP errors)

Common troubleshooting tips
- Build failure: check CloudWatch Logs for CodeBuild; ensure CodeArtifact auth token is valid and Maven settings.xml is properly configured
- CodeArtifact auth issues: verify domain name, domain owner (AWS account ID), region, and IAM permissions for get-authorization-token
- CodeDeploy agent not installed: confirm agent is installed and running on EC2 targets; check `/var/log/aws/codedeploy-agent/` logs
- Tomcat startup failures: check `/var/log/tomcat/catalina.out` for Java errors and ensure WAR file was copied correctly
- Apache proxy issues: verify Apache configuration in `/etc/httpd/conf.d/tomcat_manager.conf` and ensure port 8080 is accessible
- Permissions errors: validate IAM role trust relationships and that CodePipeline can pass roles for CodeBuild/CodeDeploy
- Artifact not found: confirm artifact names in pipeline stage configuration and S3 object keys
- Security Group blocking access: ensure your IP address is correctly specified in the MyIP CloudFormation parameter

Security considerations
- Use least-privilege IAM policies and separate roles for pipeline services
- Store secrets (e.g., GitHub token, CodeArtifact tokens) in AWS Secrets Manager or Parameter Store and reference them in CodeBuild as encrypted environment variables
- Protect CodeArtifact domain with resource policies and restrict domain owner and repository access
- Enable encryption at rest for S3 artifacts and use KMS keys where required

Cost considerations
- CodePipeline and CodeBuild have per-minute and per-pipeline costs; evaluate build frequency and optimize build times
- EC2 instances incur hourly charges; consider using smaller instance types or spot instances for development
- CodeArtifact has storage and request costs; implement retention policies for old package versions
- S3 storage costs for build artifacts; enable lifecycle policies to archive or delete old artifacts
- Data transfer costs for internet egress from EC2 instances

Examples & snippets to get started quickly
- Creating the infrastructure with CloudFormation:
  ```bash
  aws cloudformation create-stack \
    --stack-name nextwork-web-stack \
    --template-body file://nextworkwebapp.yaml \
    --parameters ParameterKey=MyIP,ParameterValue=$(curl -s checkip.amazonaws.com)/32 \
    --capabilities CAPABILITY_IAM \
    --region ap-south-1
  ```
- Creating a CodeBuild project (CLI concept):
  ```bash
  aws codebuild create-project \
    --name nextwork-build \
    --source type=GITHUB,location=https://github.com/ARJ2004/nextwork-web-project \
    --artifacts type=S3,location=my-pipeline-artifacts-bucket \
    --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:5.0,computeType=BUILD_GENERAL1_MEDIUM \
    --service-role arn:aws:iam::123456789012:role/CodeBuildServiceRole
  ```
- Create a CodePipeline with stages: Source (GitHub) -> Build (CodeBuild) -> Deploy (CodeDeploy)
- Install CodeDeploy agent on EC2:
  ```bash
  sudo yum install -y ruby wget
  cd /home/ec2-user
  wget https://aws-codedeploy-ap-south-1.s3.ap-south-1.amazonaws.com/latest/install
  chmod +x ./install
  sudo ./install auto
  sudo service codedeploy-agent start
  ```

Repository structure suggestion
- /src                        # Java application source code
- /src/main/webapp           # Web application resources (JSP, HTML, etc.)
- /scripts                   # CodeDeploy lifecycle hook scripts
  - install_dependencies.sh  # Install Tomcat and Apache
  - start_server.sh          # Start services
  - stop_server.sh           # Stop services
- pom.xml                    # Maven project configuration
- buildspec.yml              # CodeBuild build specification
- appspec.yml                # CodeDeploy deployment specification
- settings.xml               # Maven settings for CodeArtifact authentication
- nextworkwebapp.yaml        # CloudFormation template for infrastructure
- README.md                  # This documentation

What I created in this README
I documented a clear, reproducible CI/CD pipeline pattern using CodePipeline, CodeBuild, CodeDeploy, and CodeArtifact for a Java web application. The README includes:
- CloudFormation template documentation for infrastructure provisioning
- Maven/Java buildspec configuration with CodeArtifact integration
- EC2 deployment with Tomcat and Apache HTTP server
- Lifecycle hooks for safe deployments
- IAM and authentication guidance
- Common troubleshooting for Java/Tomcat deployments
- Step-by-step deployment instructions

What's next
- Enhance the CloudFormation template to include Auto Scaling Group for high availability
- Add CloudFormation/Terraform templates for the complete CI/CD pipeline (CodePipeline, CodeBuild, CodeDeploy)
- Implement Blue-Green deployment strategy with CodeDeploy
- Add comprehensive health check and validation scripts
- Integrate application monitoring with CloudWatch and X-Ray
- Add automated testing in the build phase (unit tests, integration tests)
- Implement canary deployments for safer production rollouts
- Add multi-region deployment capability

Contributing
If you'd like to extend the pipeline examples (Auto Scaling Groups, Blue-Green deployments, Terraform automation, multi-region deployment, containerization with ECS), open a PR or file an issue describing the enhancement.

Author
ARJ2004 — CI/CD pipeline examples and configuration for Nextwork

License
MIT
