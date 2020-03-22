variable "account_id" {
  type    = "string"
  default = ""
}

variable "region" {
  type    = "string"
  default = "us-east-1"
}

provider "aws" {
  region  = "us-east-1"
  version = "~> 2.0"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "test-bucket-29999"
}

resource "aws_sns_topic" "topic" {
  name = "aws-sns-topic"

  policy = <<POLICY
  {
      "Version":"2012-10-17",
      "Statement":[{
          "Effect": "Allow",
          "Principal": {"Service":"s3.amazonaws.com"},
          "Action": "SNS:Publish",
          "Resource":  "arn:aws:sns:${var.region}:${var.account_id}:aws-sns-topic",
          "Condition":{
              "ArnLike":{"aws:SourceArn":"${aws_s3_bucket.bucket.arn}"}
          }
      }]
  }
  POLICY
}

resource "aws_s3_bucket_notification" "s3_notif" {
  bucket = "${aws_s3_bucket.bucket.id}"

  topic {
    topic_arn = "${aws_sns_topic.topic.arn}"

    events = [
      "s3:ObjectCreated:*",
    ]

  }
}

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.func.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.topic.arn}"
}


resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = "${aws_sns_topic.topic.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.func.arn}"
}

provider "archive" {}

data "archive_file" "zip" {
  type        = "zip"
  output_path = "/tmp/lambda_zip_inline.zip"
  source {
    content  = <<EOF
import json

print('Loading function')

def lambda_handler(event, context):
    print("Received event: " + json.dumps(event, indent=2))
    return "event firing"
EOF
    filename = "lambda.py"
  }
}

data "aws_iam_policy" "ReadOnlyAccess" {
  arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role" "default" {
  name = "iam_for_lambda_with_sns"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "cloudwatchfullaccess-role-policy-attach" {
  role       = "${aws_iam_role.default.name}"
  policy_arn = "${data.aws_iam_policy.ReadOnlyAccess.arn}"
}

resource "aws_lambda_function" "func" {
  filename         = "${data.archive_file.zip.output_path}"
  source_code_hash = "${data.archive_file.zip.output_base64sha256}"
  function_name = "lambda_handler"
  role          = "${aws_iam_role.default.arn}"
  handler       = "lambda.lambda_handler"
  runtime       = "python3.7"
  memory_size   = "128"
  timeout       = "60"
}