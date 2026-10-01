"""CloudWatch alarms + dashboard (spec: never silently lose a reminder)."""

from aws_cdk import Duration, Stack, aws_cloudwatch as cw, aws_cloudwatch_actions as cw_actions
from aws_cdk import aws_lambda as lambda_, aws_rds as rds, aws_sns as sns, aws_sqs as sqs
from aws_cdk import aws_sns_subscriptions as subs
from constructs import Construct


class MonitoringStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        *,
        api_fn: lambda_.IFunction,
        processor: lambda_.IFunction,
        dispatcher: lambda_.IFunction,
        dlq: sqs.IQueue,
        cluster: rds.IDatabaseCluster,
        **kwargs,
    ) -> None:
        super().__init__(scope, id, **kwargs)

        self.alarm_topic = sns.Topic(self, "AlarmTopic", display_name="Personal Memory OS alarms")
        email = self.node.try_get_context("alarm_email")
        if email:
            self.alarm_topic.add_subscription(subs.EmailSubscription(email))
        action = cw_actions.SnsAction(self.alarm_topic)

        def alarm(name: str, metric: cw.IMetric, threshold: float, description: str) -> cw.Alarm:
            a = cw.Alarm(
                self,
                name,
                metric=metric,
                threshold=threshold,
                evaluation_periods=1,
                comparison_operator=cw.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
                treat_missing_data=cw.TreatMissingData.NOT_BREACHING,
                alarm_description=description,
            )
            a.add_alarm_action(action)
            return a

        five = Duration.minutes(5)
        alarm("ApiErrors", api_fn.metric_errors(period=five), 5, "API Lambda is failing")
        alarm("ApiThrottles", api_fn.metric_throttles(period=five), 1, "API Lambda is throttled")
        # A failing dispatcher means a cloud reminder did not go out: alarm on the first one.
        alarm("DispatcherErrors", dispatcher.metric_errors(period=five), 1, "Reminder push delivery failed")
        alarm("ProcessorErrors", processor.metric_errors(period=five), 3, "Capture processing is failing")
        alarm(
            "CaptureDlqNotEmpty",
            dlq.metric_approximate_number_of_messages_visible(period=five),
            1,
            "Captures landed in the dead-letter queue",
        )
        alarm(
            "DatabaseCpu",
            cluster.metric_cpu_utilization(period=five),
            80,
            "Aurora CPU is high",
        )

        cw.Dashboard(
            self,
            "Dashboard",
            dashboard_name="personal-memory-os",
            widgets=[
                [
                    cw.GraphWidget(title="API invocations / errors", left=[api_fn.metric_invocations(), api_fn.metric_errors()]),
                    cw.GraphWidget(title="API p95 latency", left=[api_fn.metric_duration(statistic="p95")]),
                ],
                [
                    cw.GraphWidget(title="Reminder dispatch", left=[dispatcher.metric_invocations(), dispatcher.metric_errors()]),
                    cw.GraphWidget(title="Capture processing", left=[processor.metric_invocations(), processor.metric_errors()]),
                ],
                [
                    cw.GraphWidget(title="DLQ depth", left=[dlq.metric_approximate_number_of_messages_visible()]),
                    cw.GraphWidget(title="Aurora CPU", left=[cluster.metric_cpu_utilization()]),
                ],
            ],
        )
