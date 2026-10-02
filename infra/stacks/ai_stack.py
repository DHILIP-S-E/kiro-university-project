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

        # Guardrail applied to every Claude call (reminder parsing, event extraction,
        # summaries, memory Q&A, capture summaries). Personal content is legitimately
        # full of names and dates, so PII is not masked; only credentials are.
        filters = [
            bedrock.CfnGuardrail.ContentFilterConfigProperty(
                type=t, input_strength="HIGH", output_strength="HIGH"
            )
            for t in ("HATE", "INSULTS", "SEXUAL", "VIOLENCE", "MISCONDUCT")
        ] + [
            # Prompt-injection defence for pasted web pages and shared text.
            bedrock.CfnGuardrail.ContentFilterConfigProperty(
                type="PROMPT_ATTACK", input_strength="HIGH", output_strength="NONE"
            )
        ]
        self.guardrail = bedrock.CfnGuardrail(
            self,
            "Guardrail",
            name="personal-memory-os",
            description="Content safety and credential masking for all model calls",
            blocked_input_messaging="That request can't be processed.",
            blocked_outputs_messaging="That answer was withheld by the safety policy.",
            content_policy_config=bedrock.CfnGuardrail.ContentPolicyConfigProperty(filters_config=filters),
            sensitive_information_policy_config=bedrock.CfnGuardrail.SensitiveInformationPolicyConfigProperty(
                pii_entities_config=[
                    bedrock.CfnGuardrail.PiiEntityConfigProperty(type=t, action="ANONYMIZE")
                    for t in ("AWS_ACCESS_KEY", "AWS_SECRET_KEY", "PASSWORD")
                ]
            ),
        )
        # Numbered versions are immutable; callers pin this one.
        self.guardrail_version = bedrock.CfnGuardrailVersion(
            self,
            "GuardrailVersion",
            guardrail_identifier=self.guardrail.attr_guardrail_id,
        )
        self.guardrail_id = self.guardrail.attr_guardrail_id
        self.guardrail_arn = self.guardrail.attr_guardrail_arn
        self.guardrail_version_number = self.guardrail_version.attr_version

        # Cross-region inference profile required by InvokeDataAutomationAsync.
        self.profile_arn = f"arn:aws:bedrock:{self.region}:{self.account}:data-automation-profile/{prefix}.data-automation-v1"

        CfnOutput(self, "GuardrailId", value=self.guardrail_id)
        CfnOutput(self, "BdaProjectArn", value=self.bda_project.attr_project_arn)
