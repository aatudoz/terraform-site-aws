# Website project
Live: https://d2pyc1f7rxko9t.cloudfront.net

This project was made to learn more about cloud infrastructure, including hosting and securing a website using AWS S3 and CloudFront.
It is entirely hosted on AWS and deployed automatically when I push code to Git.
Lastly, every piece of infrastructure is defined by code.


## Storage S3
This project holds two S3 buckets:
  - one bucket for the website files/images (.html, CSS, JS)
  - one bucket for the Terraform State file

Both buckets are private and cant be directly accessed via public internet.
Website files were uploaded via Terraform during deployment.

## CloudFront
CloudFront sits infront of our S3 and serves the website over HTTPS, since S3 static website hosting doesnt support HTTPS by itself.
The site bucket only allows read access from this CloudFront distribution.

Access is handled with Origin Access Control (OAC), which lets CloudFront access the private S3 bucket without making the bucket public.


## Terraform (IAC)
A fun challenge was to get every AWS resouce declared in main.tf
All AWS resources are declared in main.tf, so the infrastructure can be recreated from code instead of being configured manually.
Terraforms statefile is stored remotely in a seperate S3 bucket so any machine can run Terraform.

## CI/CD 
This pipeline triggers automatically on every push to main (Git) without revealing AWS credentials.
It runs a fresh Linux machine everytime, 
  - checks the code,
    - authenticates itself to AWS,
      - installs Terraform,
        - runs terraform init and apply,
          - lastly refreshes CloudFront cache to update "instantly".

Meaning changes pushed to main gets deployed automatically without manual steps.

## Security
Github Actions authenticates itself to AWS using OIDC, so no AWS access keys are stored in this repo or CI secrets.
Access gets limited through an IAM role with a trust policy only to this repo.
AWS issues temporary credentials during the workflow run, meaning they expire automatically after a short time.


# TBD:
Currently I have a drawing minigame on the site which was just vibecoded via Claude.
In the future I will display peoples drawings on the site, which will need a serverless backend with AWS Lambda functions behind API Gateway to handle uploads and a dedicated S3 bucket.
