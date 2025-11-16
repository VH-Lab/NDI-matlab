"""
NDI Simple Calculator - A simple demonstration calculator.

This module provides a simple demonstration of an ndi.calculator object
that produces output documents with an 'answer' field from input parameters.
"""

from typing import Dict, Any, List
from ...calculator import Calculator


class Simple(Calculator):
    """
    Simple demonstration calculator.

    This calculator is a demonstration that simply produces the 'answer'
    that is provided in the input parameters. Each simple_calc document
    'depends_on' an NDI probe.

    The purpose is to demonstrate the calculator framework and provide
    a template for creating new calculators.

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> calc = Simple(session)
        >>> params = calc.default_search_for_input_parameters()
        >>> docs = calc.run('NoAction', params)
    """

    def __init__(self, session: Any):
        """
        Create a Simple calculator object.

        Args:
            session: The ndi.session object to operate on

        Examples:
            >>> calc = Simple(session)
        """
        # Initialize with document type information
        # In a real implementation, this would point to a JSON schema
        super().__init__(
            session,
            'simple_calc',
            'simple_calc.json'  # Would be full path in production
        )

    def calculate(self, parameters: Dict[str, Any]) -> Any:
        """
        Perform the calculation for ndi.calc.example.simple.

        Creates a simple_calc document given input parameters.
        The document simply has an 'answer' field from the input parameters.

        Args:
            parameters: Parameter structure with:
                - input_parameters: Must contain 'answer' field
                - depends_on: List of dependency structures

        Returns:
            ndi.document with simple_calc results

        Raises:
            ValueError: If required parameters are missing

        Examples:
            >>> params = {
            ...     'input_parameters': {'answer': 42},
            ...     'depends_on': [{'name': 'probe_id', 'value': 'abc123...'}]
            ... }
            >>> doc = calc.calculate(params)
            >>> doc.document_properties.simple.answer
            42
        """
        # Check inputs
        if 'input_parameters' not in parameters:
            raise ValueError('parameters structure lacks "input_parameters"')
        if 'depends_on' not in parameters:
            raise ValueError('parameters structure lacks "depends_on"')

        # Step 1: Set up the output structure
        simple = parameters.copy()

        # Step 2: Perform the calculation (simple one-line statement)
        simple['answer'] = parameters['input_parameters']['answer']

        # Step 3: Place results into an NDI document
        from ...document import Document
        doc = Document(self.doc_document_types[0], 'simple', simple)

        # Set dependencies
        for dep in parameters['depends_on']:
            doc = doc.set_dependency_value(dep['name'], dep['value'])

        return doc

    def default_search_for_input_parameters(self) -> Dict[str, Any]:
        """
        Return default parameters for searching for inputs.

        Returns:
            Dictionary with default search parameters

        Examples:
            >>> calc = Simple(session)
            >>> params = calc.default_search_for_input_parameters()
            >>> params['input_parameters']['answer']
            5
        """
        from ...query import Query

        return {
            'input_parameters': {'answer': 5},
            'depends_on': [],
            'query': [{
                'name': 'probe_id',
                'query': Query('element.ndi_element_class', 'contains_string', 'ndi.probe', '')
            }]
        }

    def doc_about(self) -> str:
        """
        Return documentation about the simple_calc calculator.

        Returns:
            Documentation string

        Examples:
            >>> calc = Simple(session)
            >>> text = calc.doc_about()
            >>> 'SIMPLE_CALC' in text
            True
        """
        return """
        ----------------------------------------------------------------------------------------------
        NDI_CALCULATOR: SIMPLE_CALC
        ----------------------------------------------------------------------------------------------

           ------------------------
           | SIMPLE_CALC -- ABOUT |
           ------------------------

           SIMPLE_CALC is a demonstration document. It simply produces the 'answer' that
           is provided in the input parameters. Each SIMPLE_CALC document 'depends_on' an
           NDI probe.

           This serves as a template for creating new calculator implementations.

           Definition: simple_calc.json
        """
