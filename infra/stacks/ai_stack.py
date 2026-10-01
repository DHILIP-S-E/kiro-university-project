"""Bedrock Data Automation project for photo / document extraction (spec R3.5).

Voice notes go through Amazon Transcribe (started by the capture processor).
"""

from aws_cdk import CfnOutput, Stack, aws_bedrock as bedrock
from constructs import Construct


class AiStack(Stack):
    def __init__(self, scope: Construct, id: str, **kwargs) -> None:
        super().__init__(scope, id, **kwargs)

        prefix = self.node.try_get_context("bda_profile_prefix") or "us"

        self.bda_project = bedrock.CfnDataAutomationProject(
            self,
            "CaptureExtraction",
            project_name="personal-memory-os-captures",
            project_description="Extract text, summaries and key points from photos and documents",
            standard_output_configuration=bedrock.CfnDataAutomationProject.StandardOutputConfigurationProperty(
                document=bedrock.CfnDataAutomationProject.DocumentStandardOutputConfigurationProperty(
                    extraction=bedrock.CfnDataAutomationProject.DocumentStandardExtractionProperty(
                        granularity=bedrock.CfnDataAutomationProject.DocumentExtractionGranularityProperty(
                            types=["DOCUMENT", "PAGE"]
                        ),
                        bounding_box=bedrock.CfnDataAutomationProject.DocumentBoundingBoxProperty(
                            state="DISABLED"
                        ),
                    ),
                    generative_field=bedrock.CfnDataAutomationProject.DocumentStandardGenerativeFieldProperty(
                        state="ENABLED"
                    ),
                    output_format=bedrock.CfnDataAutomationProject.DocumentOutputFormatProperty(
                        text_format=bedrock.CfnDataAutomationProject.DocumentOutputTextFormatProperty(
                            types=["MARKDOWN"]
                        ),
                        additional_file_format=bedrock.CfnDataAutomationProject.DocumentOutputAdditionalFileFormatProperty(
                            state="DISABLED"
                        ),
                    ),
                ),
                image=bedrock.CfnDataAutomationProject.ImageStandardOutputConfigurationProperty(
                    extraction=bedrock.CfnDataAutomationProject.ImageStandardExtractionProperty(
                        category=bedrock.CfnDataAutomationProject.ImageExtractionCategoryProperty(
                            state="ENABLED", types=["TEXT_DETECTION"]
                        ),
                        bounding_box=bedrock.CfnDataAutomationProject.ImageBoundingBoxProperty(
                            state="DISABLED"
                        ),
                    ),
                    generative_field=bedrock.CfnDataAutomationProject.ImageStandardGenerativeFieldProperty(
                        state="ENABLED", types=["IMAGE_SUMMARY"]
                    ),
                ),
            ),
        )

        # Cross-region inference profile required by InvokeDataAutomationAsync.
        self.profile_arn = f"arn:aws:bedrock:{self.region}:{self.account}:data-automation-profile/{prefix}.data-automation-v1"

        CfnOutput(self, "BdaProjectArn", value=self.bda_project.attr_project_arn)
