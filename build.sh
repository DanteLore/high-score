#!/usr/bin/env bash

# Directories and filenames
SRC_DIR="./lambda"
LAMBDA_BUILD_DIR="/tmp/lambda_build"
GAME_BUILD_DIR="/tmp/game_build"
ZIP_NAME="/tmp/lambda.zip"
TERRAFORM_DIR="./terraform"
GAME_DIR="./game"
AWS_S3_PATH="s3://dantelore.com/highscore"

echo "➡️ Cleaning up previous build..."
rm -rf "$LAMBDA_BUILD_DIR" "$ZIP_NAME" "$GAME_BUILD_DIR"

echo "➡️ Creating lambda package"
cp -rvf "$SRC_DIR" "$LAMBDA_BUILD_DIR"

if [ -f "requirements.txt" ]; then
  pip3 install --upgrade -r "requirements.txt" -t "$LAMBDA_BUILD_DIR"
fi

pushd $LAMBDA_BUILD_DIR
zip -r "$ZIP_NAME" .
popd

mv "$ZIP_NAME" "$TERRAFORM_DIR/"

echo "✅ Lambda package complete. Deployment package is at $TERRAFORM_DIR/$ZIP_NAME"

echo "➡️ Initializing and applying Terraform in $TERRAFORM_DIR..."
pushd "$TERRAFORM_DIR" > /dev/null

terraform init
terraform apply -auto-approve

popd > /dev/null

echo "✅ Terraform deploy completed successfully."

# Get API Gateway endpoint from Terraform output
echo "➡️ Fetching API Gateway endpoint from Terraform output..."
API_URL=$(terraform -chdir="$TERRAFORM_DIR" output -raw api_url 2>/dev/null)

echo "⚙️ API endpoint is: $API_URL"
cp -r "$GAME_DIR" "$GAME_BUILD_DIR"

find "$GAME_BUILD_DIR" -type f -name "*.html" -exec sed -i '' "s|__API_ENDPOINT__|$API_URL|g" {} +

aws s3 sync "$GAME_BUILD_DIR" "$AWS_S3_PATH" --acl public-read

echo "✅ Game files uploaded to S3."