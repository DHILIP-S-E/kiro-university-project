"""SNS topic for push delivery (spec R7.1). Device endpoints subscribe per user."""

from aws_cdk import CfnOutput, Stack, aws_kms as kms, aws_sns as sns
from constructs import Construct


class NotificationsStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Push fan-out. Each registered device is a platform-endpoint subscription
        # with a filter policy on user_id (see backend/app/routers/devices.py), so
        # a publish tagged with user_id reaches only that user's devices.
        self.topic = sns.Topic(
            self,
            "PushTopic",
            display_name="Personal Memory OS reminders",
            master_key=kms.Alias.from_alias_name(self, "SnsManagedKey", "alias/aws/sns"),
        )

        # The FCM / APNs platform application needs credentials from your Firebase
        # / Apple developer account, so it is created out-of-band:
        #   aws sns create-platform-application --name pmos-fcm --platform GCM \
        #       --attributes PlatformCredential=<FCM server key>
        # and its ARN is passed to the API as SNS_PLATFORM_APP_ARN (see ApiStack context).
        CfnOutput(self, "PushTopicArn", value=self.topic.topic_arn)
