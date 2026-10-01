"""VPC + Aurora Serverless v2 PostgreSQL, source of truth (spec R5.4)."""

from aws_cdk import Duration, RemovalPolicy, Stack, aws_ec2 as ec2, aws_rds as rds
from constructs import Construct


class DatabaseStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        # Private subnets with NAT egress: Lambdas reach Aurora directly and AWS
        # APIs (Bedrock, SQS, SNS, Scheduler) through the NAT gateway.
        self.vpc = ec2.Vpc(
            self,
            "Vpc",
            max_azs=2,
            nat_gateways=1,
            subnet_configuration=[
                ec2.SubnetConfiguration(name="public", subnet_type=ec2.SubnetType.PUBLIC, cidr_mask=24),
                ec2.SubnetConfiguration(
                    name="private", subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS, cidr_mask=24
                ),
                ec2.SubnetConfiguration(
                    name="data", subnet_type=ec2.SubnetType.PRIVATE_ISOLATED, cidr_mask=24
                ),
            ],
        )
        # S3 traffic (media, KB documents) stays on the AWS network and off the NAT.
        self.vpc.add_gateway_endpoint("S3Endpoint", service=ec2.GatewayVpcEndpointAwsService.S3)

        # Shared by every backend Lambda; the only thing allowed to reach the database.
        self.lambda_sg = ec2.SecurityGroup(
            self, "BackendSg", vpc=self.vpc, description="Backend Lambdas", allow_all_outbound=True
        )
        db_sg = ec2.SecurityGroup(
            self, "DatabaseSg", vpc=self.vpc, description="Aurora", allow_all_outbound=False
        )
        db_sg.add_ingress_rule(self.lambda_sg, ec2.Port.tcp(5432), "Backend Lambdas")

        self.cluster = rds.DatabaseCluster(
            self,
            "Aurora",
            engine=rds.DatabaseClusterEngine.aurora_postgres(
                version=rds.AuroraPostgresEngineVersion.VER_16_4
            ),
            credentials=rds.Credentials.from_generated_secret("pmos_admin"),
            default_database_name="personal_memory_os",
            writer=rds.ClusterInstance.serverless_v2("Writer"),
            serverless_v2_min_capacity=0.5,
            serverless_v2_max_capacity=4,
            vpc=self.vpc,
            vpc_subnets=ec2.SubnetSelection(subnet_type=ec2.SubnetType.PRIVATE_ISOLATED),
            security_groups=[db_sg],
            storage_encrypted=True,
            backup=rds.BackupProps(retention=Duration.days(7)),
            deletion_protection=True,
            removal_policy=RemovalPolicy.RETAIN,
            cloudwatch_logs_exports=["postgresql"],
        )
        self.secret = self.cluster.secret
