"""
Tests for NDI ontology lookup functionality.

These tests require internet access to query external ontology APIs (EBI OLS).
They are marked as 'integration' tests and can be skipped with: pytest -m "not integration"
"""

import pytest
import json
import os
from pathlib import Path
from ndi.ontology import Ontology


# Load test cases from JSON file
def load_ontology_test_cases():
    """Load ontology test cases from JSON file."""
    test_dir = Path(__file__).parent
    json_file = test_dir / 'ontology_lookup_tests.json'

    with open(json_file, 'r') as f:
        data = json.load(f)

    test_cases = data['ontology_lookup_tests']

    # Create test IDs for better test output
    test_ids = [f"{case['ontology']}:{case['lookup_string'].replace(':', '_')}"
                for case in test_cases]

    return test_cases, test_ids


# Load all test cases
ALL_TEST_CASES, TEST_IDS = load_ontology_test_cases()


@pytest.mark.integration
@pytest.mark.slow
@pytest.mark.parametrize('test_case', ALL_TEST_CASES, ids=TEST_IDS)
def test_ontology_lookup(test_case):
    """
    Test ontology lookup functionality with various ontologies.

    This is a parameterized test that loads test cases from a JSON file.
    Each test case specifies:
    - lookup_string: The string to look up
    - should_succeed: Whether the lookup should succeed or fail
    - expected_id: The expected ID returned (if success)
    - expected_name: The expected name returned (if success)
    """
    lookup_str = test_case['lookup_string']
    should_succeed = test_case['should_succeed']
    expected_id = test_case['expected_id']
    expected_name = test_case['expected_name']

    if should_succeed:
        # Test case expected to succeed
        try:
            result_id, result_name, _, _, _ = Ontology.lookup(lookup_str)

            # Verify ID matches
            assert result_id == expected_id, \
                f'ID mismatch for "{lookup_str}". Expected "{expected_id}", got "{result_id}"'

            # Verify name matches (case-insensitive)
            assert result_name.lower() == expected_name.lower(), \
                f'Name mismatch for "{lookup_str}". Expected "{expected_name}", got "{result_name}"'

        except Exception as e:
            pytest.fail(f'Expected success for "{lookup_str}", but got error: {str(e)}')

    else:
        # Test case expected to fail
        with pytest.raises(Exception):
            Ontology.lookup(lookup_str)


# Create a separate test for a quick smoke test that doesn't require all API calls
@pytest.mark.integration
def test_ontology_lookup_basic():
    """
    Quick smoke test for ontology lookup with a simple case.

    This test can be run individually for quick verification that the
    ontology lookup system is working without running all test cases.
    """
    # Test a simple lookup that should work
    result_id, result_name, _, _, _ = Ontology.lookup('CL:0000000')
    assert result_id == 'CL:0000000', 'Expected cell type ontology ID'
    assert result_name.lower() == 'cell', f'Expected "cell", got "{result_name}"'


@pytest.mark.integration
def test_ontology_lookup_invalid():
    """Test that invalid lookups raise an error."""
    with pytest.raises(Exception):
        Ontology.lookup('InvalidOntology:NoSuchTerm')
