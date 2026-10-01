"""OpenSearch Serverless vector store + Bedrock Knowledge Base (spec R4.2, R4.3)."""

import json

from aws_cdk import (
    CfnOutput,
    CustomResource,
    Duration,
    Stack,
    aws_bedrock as bedrock,
    aws_iam as iam,
    aws_kms as kms,
    aws_lambda as lambda_,
    aws_opensearchserverless as aoss,
    aws_s3 as s3,
    custom_resources as cr,
)
from constructs import Construct

from stacks.common import EMBEDDING_MODEL

COLLECTION_NAME = "pmos-memory"
INDEX_NAME = "pmos-memory-index"
VECTOR_FIELD = "embedding"
TEXT_FIELD = "text"
METADATA_FIELD = "metadata"
EMBEDDING_DIMENSIONS = 1024  # amazon.titan-embed-text-v2:0 default

# CloudFormation cannot create an OpenSearch index, so a custom resource does it.
INDEX_HANDLER = f'''
import json, time, urllib.request, urllib.error
import boto3
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

INDEX = "{INDEX_NAME}"
BODY = {{
    "settings": {{"index.knn": True}},
    "mappings": {{"properties": {{
        "{VECTOR_FIELD}": {{"type": "knn_vector", "dimension": {EMBEDDING_DIMENSIONS},
            "method": {{"name": "hnsw", "engine": "faiss", "space_type": "l2"}}}},
        "{TEXT_FIELD}": {{"type": "text"}},
        "{METADATA_FIELD}": {{"type": "text"}},
    }}}},
}}

def _request(endpoint, method, path, body=None):
    url = endpoint.rstrip("/") + path
    data = json.dumps(body).encode() if body is not None else None
    creds = boto3.Session().get_credentials()
    region = boto3.Session().region_name
    req = AWSRequest(method=method, url=url, data=data, headers={{"Content-Type": "application/json"}})
    SigV4Auth(creds, "aoss", region).add_auth(req)
    r = urllib.request.Request(url, data=data, method=method, headers=dict(req.headers))
    with urllib.request.urlopen(r, timeout=30) as resp:
        return resp.status

def handler(event, _ctx):
    props = event["ResourceProperties"]
    endpoint = props["Endpoint"]
    if event["RequestType"] == "Delete":
        return {{"PhysicalResourceId": INDEX}}
    # Data-access policies take a while to propagate: retry on 403.
    last = None
    for _ in range(20):
        try:
            _request(endpoint, "PUT", "/" + INDEX, BODY)
            break
        except urllib.error.HTTPError as e:
            if e.code == 400 and b"resource_already_exists" in e.read():
                break
            last = e
            time.sleep(15)
    else:
        raise RuntimeError(f"Could not create index: {{last}}")
    time.sleep(30)  # let the index become visible to Bedrock
    return {{"PhysicalResourceId": INDEX}}
'''


class SearchStack(Stack):
    def __init__(
        self,
        scope: Construct,
        id: str,
        *,
        bucket: s3.IBucket,
        data_key: kms.IKey,
        **kwargs,
    ) -> None:
        super().__init__(scope, id, **kwargs)

        # -- Bedrock service role: read the bucket, embed, write the vector index --
        kb_role = iam.Role(
            self,
            "KnowledgeBaseRole",
            assumed_by=iam.ServicePrincipal(
                "bedrock.amazonaws.com",
                conditions={"StringEquals": {"aws:SourceAccount": self.account}},
            ),
        )
        kb_role.add_to_policy(
            iam.PolicyStatement(
                actions=["bedrock:InvokeModel"],
                resources=[f"arn:aws:bedrock:{self.region}::foundation-model/{EMBEDDING_MODEL}"],
            )
        )
        bucket.grant_read(kb_role, "knowledge/*")
        kb_role.add_to_policy(
            iam.PolicyStatement(actions=["s3:ListBucket"], resources=[bucket.bucket_arn])
        )
        data_key.grant_decrypt(kb_role)

        # -- Index creator role --
        index_fn = lambda_.Function(
            self,
            "IndexCreator",
            runtime=lambda_.Runtime.PYTHON_3_12,
            handler="index.handler",
            code=lambda_.Code.from_inline(INDEX_HANDLER),
            timeout=Duration.minutes(5),
        )

        # -- Collection + policies --
        encryption = aoss.CfnSecurityPolicy(
            self,
            "EncryptionPolicy",
            name=f"{COLLECTION_NAME}-enc",
            type="encryption",
            policy=json.dumps({
                "Rules": [{"ResourceType": "collection", "Resource": [f"collection/{COLLECTION_NAME}"]}],
                "AWSOwnedKey": True,
            }),
        )
        network = aoss.CfnSecurityPolicy(
            self,
            "NetworkPolicy",
            name=f"{COLLECTION_NAME}-net",
            type="network",
            # Public endpoint; access is still restricted to the principals in the
            # data-access policy below (IAM/SigV4 only).
            policy=json.dumps([{
                "Rules": [{"ResourceType": "collection", "Resource": [f"collection/{COLLECTION_NAME}"]}],
                "AllowFromPublic": True,
            }]),
        )
        collection = aoss.CfnCollection(
            self, "Collection", name=COLLECTION_NAME, type="VECTORSEARCH",
            description="Personal memory embeddings",
        )
        collection.add_dependency(encryption)
        collection.add_dependency(network)

        access = aoss.CfnAccessPolicy(
            self,
            "DataAccessPolicy",
            name=f"{COLLECTION_NAME}-access",
            type="data",
            policy=json.dumps([{
                "Rules": [
                    {
                        "ResourceType": "index",
                        "Resource": [f"index/{COLLECTION_NAME}/*"],
                        "Permission": [
                            "aoss:CreateIndex", "aoss:DescribeIndex", "aoss:ReadDocument",
                            "aoss:WriteDocument", "aoss:UpdateIndex", "aoss:DeleteIndex",
                        ],
                    },
                    {
                        "ResourceType": "collection",
                        "Resource": [f"collection/{COLLECTION_NAME}"],
                        "Permission": ["aoss:DescribeCollectionItems", "aoss:CreateCollectionItems", "aoss:UpdateCollectionItems"],
                    },
                ],
                "Principal": [kb_role.role_arn, index_fn.role.role_arn],
            }]),
        )
        access.add_dependency(collection)

        for role in (kb_role, index_fn.role):
            role.add_to_principal_policy(
                iam.PolicyStatement(actions=["aoss:APIAccessAll"], resources=[collection.attr_arn])
            )

        provider = cr.Provider(self, "IndexProvider", on_event_handler=index_fn)
        index = CustomResource(
            self,
            "VectorIndex",
            service_token=provider.service_token,
            properties={"Endpoint": collection.attr_collection_endpoint, "Index": INDEX_NAME},
        )
        index.node.add_dependency(access)

        # -- Knowledge Base over knowledge/ in the captures bucket --
        self.knowledge_base = bedrock.CfnKnowledgeBase(
            self,
            "KnowledgeBase",
            name="personal-memory-os",
            role_arn=kb_role.role_arn,
            knowledge_base_configuration=bedrock.CfnKnowledgeBase.KnowledgeBaseConfigurationProperty(
                type="VECTOR",
                vector_knowledge_base_configuration=bedrock.CfnKnowledgeBase.VectorKnowledgeBaseConfigurationProperty(
                    embedding_model_arn=f"arn:aws:bedrock:{self.region}::foundation-model/{EMBEDDING_MODEL}"
                ),
            ),
            storage_configuration=bedrock.CfnKnowledgeBase.StorageConfigurationProperty(
                type="OPENSEARCH_SERVERLESS",
                opensearch_serverless_configuration=bedrock.CfnKnowledgeBase.OpenSearchServerlessConfigurationProperty(
                    collection_arn=collection.attr_arn,
                    vector_index_name=INDEX_NAME,
                    field_mapping=bedrock.CfnKnowledgeBase.OpenSearchServerlessFieldMappingProperty(
                        vector_field=VECTOR_FIELD,
                        text_field=TEXT_FIELD,
                        metadata_field=METADATA_FIELD,
                    ),
                ),
            ),
        )
        self.knowledge_base.node.add_dependency(index)

        self.data_source = bedrock.CfnDataSource(
            self,
            "MemoryDocuments",
            name="memory-documents",
            knowledge_base_id=self.knowledge_base.attr_knowledge_base_id,
            data_source_configuration=bedrock.CfnDataSource.DataSourceConfigurationProperty(
                type="S3",
                s3_configuration=bedrock.CfnDataSource.S3DataSourceConfigurationProperty(
                    bucket_arn=bucket.bucket_arn,
                    inclusion_prefixes=["knowledge/"],
                ),
            ),
            vector_ingestion_configuration=bedrock.CfnDataSource.VectorIngestionConfigurationProperty(
                chunking_configuration=bedrock.CfnDataSource.ChunkingConfigurationProperty(
                    chunking_strategy="FIXED_SIZE",
                    fixed_size_chunking_configuration=bedrock.CfnDataSource.FixedSizeChunkingConfigurationProperty(
                        max_tokens=300, overlap_percentage=20
                    ),
                )
            ),
        )

        self.knowledge_base_id = self.knowledge_base.attr_knowledge_base_id
        self.data_source_id = self.data_source.attr_data_source_id
        self.knowledge_base_arn = self.knowledge_base.attr_knowledge_base_arn

        CfnOutput(self, "KnowledgeBaseId", value=self.knowledge_base_id)
        CfnOutput(self, "DataSourceId", value=self.data_source_id)
