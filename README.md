# Description
S3 object creation event funnels through SNS to a Lambda function. The event object gets parsed and the filename of the uploaded file in the S3 bucket is sent to an external service using an HTTP post request. You can see the event logs in CloudWatch.

# Prerequisites
* Active AWS account
* AWS credentials configured for CLI

# Usage
1. `terraform init` (first time only)
2. `terraform validate`
3. `terraform apply`
