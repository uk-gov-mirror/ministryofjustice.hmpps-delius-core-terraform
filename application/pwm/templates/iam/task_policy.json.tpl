{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListObjects", "s3:GetObject"],
      "Resource": ["${bucket}/*"]
    }
  ]
}