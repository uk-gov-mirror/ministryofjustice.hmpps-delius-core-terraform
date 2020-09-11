resource "aws_lambda_function" "notify_slack_alarm" {
  runtime          = "nodejs12.x"
  role             = "${data.aws_iam_role.lambda_exec_role.arn}"
  filename         = "${data.archive_file.alarm_lambda_handler_zip.output_path}"
  function_name    = "${local.lambda_name_alarm}"
  handler          = "notify-slack-alarm.handler"
  source_code_hash = "${base64sha256(file("${data.archive_file.alarm_lambda_handler_zip.output_path}"))}"
}

resource "aws_lambda_permission" "sns_alarm" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.notify_slack_alarm.arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.alarm_notification.arn}"
}


resource "aws_lambda_function" "notify_slack_batch" {
  runtime          = "nodejs12.x"
  role             = "${data.aws_iam_role.lambda_exec_role.arn}"
  filename         = "${data.archive_file.batch_lambda_handler_zip.output_path}"
  function_name    = "${local.lambda_name_batch}"
  handler          = "notify-slack-batch.handler"
  source_code_hash = "${base64sha256(file("${data.archive_file.batch_lambda_handler_zip.output_path}"))}"
}

resource "aws_lambda_permission" "sns_batch" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.notify_slack_batch.arn}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.batch_notification.arn}"
}