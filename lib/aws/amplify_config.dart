/// AWS Amplify configuration.
/// Replace values with your real Amplify outputs after running `amplify push`.
/// Never commit real credentials — use environment variables or
/// AWS Secrets Manager in CI/CD.
const amplifyconfig = '''{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/0.1.0",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CredentialsProvider": {
          "CognitoIdentity": {
            "Default": {
              "PoolId": "REPLACE_WITH_IDENTITY_POOL_ID",
              "Region": "us-east-1"
            }
          }
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "REPLACE_WITH_USER_POOL_ID",
            "AppClientId": "REPLACE_WITH_APP_CLIENT_ID",
            "Region": "us-east-1"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_SRP_AUTH",
            "socialProviders": ["GOOGLE"],
            "usernameAttributes": ["EMAIL"],
            "signupAttributes": ["EMAIL"],
            "passwordProtectionSettings": {
              "passwordPolicyMinLength": 8,
              "passwordPolicyCharacters": []
            },
            "mfaConfiguration": "OFF",
            "mfaTypes": [],
            "verificationMechanisms": ["EMAIL"]
          }
        }
      }
    }
  },
  "api": {
    "plugins": {
      "awsAPIPlugin": {
        "personalMemoryApi": {
          "endpointType": "GraphQL",
          "endpoint": "REPLACE_WITH_APPSYNC_ENDPOINT",
          "region": "us-east-1",
          "authorizationType": "AMAZON_COGNITO_USER_POOLS"
        }
      }
    }
  },
  "storage": {
    "plugins": {
      "awsS3StoragePlugin": {
        "bucket": "REPLACE_WITH_S3_BUCKET_NAME",
        "region": "us-east-1",
        "defaultAccessLevel": "private"
      }
    }
  }
}''';
