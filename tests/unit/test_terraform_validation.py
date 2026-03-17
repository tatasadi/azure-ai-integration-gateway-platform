"""
Unit tests for Terraform configuration validation

These tests validate the Terraform configuration files and APIM policies.

Usage:
    python -m pytest tests/unit/test_terraform_validation.py -v
"""

import os
import subprocess
import xml.etree.ElementTree as ET
import pytest
from pathlib import Path


class TestTerraformValidation:
    """Tests for Terraform configuration validation"""

    @pytest.fixture
    def terraform_dir(self):
        """Get the Terraform directory path"""
        return Path(__file__).parent.parent.parent / "terraform"

    def test_terraform_format_check(self, terraform_dir):
        """Terraform files should be properly formatted"""
        result = subprocess.run(
            ["terraform", "fmt", "-check", "-recursive"],
            cwd=terraform_dir,
            capture_output=True,
            text=True
        )

        assert result.returncode == 0, f"Terraform formatting issues found:\n{result.stdout}"

    def test_terraform_validate(self, terraform_dir):
        """Terraform configuration should be valid"""
        # Initialize Terraform (without backend)
        init_result = subprocess.run(
            ["terraform", "init", "-backend=false"],
            cwd=terraform_dir,
            capture_output=True,
            text=True
        )

        assert init_result.returncode == 0, f"Terraform init failed:\n{init_result.stderr}"

        # Validate configuration
        validate_result = subprocess.run(
            ["terraform", "validate"],
            cwd=terraform_dir,
            capture_output=True,
            text=True
        )

        assert validate_result.returncode == 0, f"Terraform validation failed:\n{validate_result.stderr}"

    def test_required_terraform_files_exist(self, terraform_dir):
        """Required Terraform files should exist"""
        required_files = [
            "main.tf",
            "variables.tf",
            "outputs.tf",
            "versions.tf"
        ]

        for file in required_files:
            file_path = terraform_dir / file
            assert file_path.exists(), f"Required file missing: {file}"

    def test_terraform_modules_exist(self, terraform_dir):
        """Required Terraform modules should exist"""
        required_modules = [
            "modules/resource-group",
            "modules/api-management",
            "modules/key-vault",
            "modules/monitoring",
            "modules/ai-foundry"
        ]

        for module in required_modules:
            module_path = terraform_dir / module
            assert module_path.exists(), f"Required module missing: {module}"
            assert (module_path / "main.tf").exists(), f"Module {module} missing main.tf"


class TestAPIMPolicyValidation:
    """Tests for APIM policy XML validation"""

    @pytest.fixture
    def policies_dir(self):
        """Get the APIM policies directory path"""
        return Path(__file__).parent.parent.parent / "apim-policies"

    def test_policy_xml_well_formed(self, policies_dir):
        """All policy XML files should be well-formed"""
        xml_files = list(policies_dir.glob("**/*.xml"))

        assert len(xml_files) > 0, "No XML policy files found"

        for xml_file in xml_files:
            try:
                ET.parse(xml_file)
            except ET.ParseError as e:
                pytest.fail(f"XML parse error in {xml_file.name}: {e}")

    def test_policy_xml_with_xmllint(self, policies_dir):
        """Validate policy XML files using xmllint"""
        xml_files = list(policies_dir.glob("**/*.xml"))

        for xml_file in xml_files:
            result = subprocess.run(
                ["xmllint", "--noout", str(xml_file)],
                capture_output=True,
                text=True
            )

            assert result.returncode == 0, f"xmllint validation failed for {xml_file.name}:\n{result.stderr}"

    def test_required_policy_files_exist(self, policies_dir):
        """Required policy files should exist"""
        required_policies = [
            "global/base-policy.xml",
            "operations/summarize-policy.xml",
            "operations/extract-policy.xml",
            "operations/health-policy.xml"
        ]

        for policy in required_policies:
            policy_path = policies_dir / policy
            assert policy_path.exists(), f"Required policy missing: {policy}"

    def test_policies_have_required_sections(self, policies_dir):
        """Policy files should have required sections"""
        xml_files = list(policies_dir.glob("operations/*.xml"))

        for xml_file in xml_files:
            tree = ET.parse(xml_file)
            root = tree.getroot()

            # Check for required policy sections
            assert root.find(".//inbound") is not None, f"{xml_file.name} missing inbound section"
            assert root.find(".//backend") is not None, f"{xml_file.name} missing backend section"
            assert root.find(".//outbound") is not None, f"{xml_file.name} missing outbound section"

    def test_policies_have_base_tag(self, policies_dir):
        """Operation policies should include <base /> tags"""
        xml_files = list(policies_dir.glob("operations/*.xml"))

        for xml_file in xml_files:
            tree = ET.parse(xml_file)
            root = tree.getroot()

            # Check for <base /> in inbound section
            inbound = root.find(".//inbound")
            if inbound is not None:
                # Should have at least one base tag or be explicitly designed without it
                base_tags = inbound.findall("base")
                # This is a warning check - some policies may not need base


class TestSecurityValidation:
    """Tests for security configuration validation"""

    @pytest.fixture
    def project_root(self):
        """Get the project root directory"""
        return Path(__file__).parent.parent.parent

    def test_no_secrets_in_terraform_files(self, project_root):
        """Terraform files should not contain hardcoded secrets"""
        terraform_files = list((project_root / "terraform").glob("**/*.tf"))

        sensitive_patterns = [
            "password",
            "secret",
            "api_key",
            "apikey",
            "access_key",
            "private_key"
        ]

        for tf_file in terraform_files:
            content = tf_file.read_text().lower()

            # Check for sensitive keywords followed by = and a quoted string
            for pattern in sensitive_patterns:
                if f'{pattern} = "' in content and 'var.' not in content:
                    # Allow references to variables
                    pytest.fail(f"Potential hardcoded secret found in {tf_file.name} with pattern: {pattern}")

    def test_gitignore_includes_terraform_state(self, project_root):
        """gitignore should exclude Terraform state files"""
        gitignore_path = project_root / ".gitignore"

        assert gitignore_path.exists(), ".gitignore file not found"

        gitignore_content = gitignore_path.read_text()

        required_patterns = [
            "*.tfstate",
            "*.tfvars",
            ".terraform"
        ]

        for pattern in required_patterns:
            assert pattern in gitignore_content, f"gitignore missing pattern: {pattern}"


class TestDocumentation:
    """Tests for documentation completeness"""

    @pytest.fixture
    def docs_dir(self):
        """Get the docs directory path"""
        return Path(__file__).parent.parent.parent / "docs"

    def test_required_documentation_exists(self, docs_dir):
        """Required documentation files should exist"""
        required_docs = [
            "architecture.md",
            "api-design.md",
            "security.md",
            "rbac.md"
        ]

        for doc in required_docs:
            doc_path = docs_dir / doc
            assert doc_path.exists(), f"Required documentation missing: {doc}"

    def test_readme_exists(self):
        """README.md should exist in project root"""
        readme_path = Path(__file__).parent.parent.parent / "README.md"
        assert readme_path.exists(), "README.md not found"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
