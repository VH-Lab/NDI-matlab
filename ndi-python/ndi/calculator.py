"""
NDI Calculator - Base class for NDI calculators.

This module provides the Calculator class for performing calculations on NDI
data and creating calculation documents.
"""

import logging
from typing import List, Dict, Any, Optional, Tuple
from .app import App
from .appdoc import AppDoc


class Calculator(App, AppDoc):
    """
    Base class for NDI calculators.

    A Calculator is a mini-app for performing a particular calculation on
    NDI data. It searches for appropriate inputs, performs calculations,
    and stores results as documents in the database.

    Calculators can:
    - Search for valid input parameters
    - Check for existing calculation documents
    - Perform calculations and create result documents
    - Generate diagnostic plots

    Attributes:
        session: The ndi.session object to operate on
        name: The name of the calculator
        doc_types: List of document types this calculator uses
        doc_document_types: List of NDI document datatypes
        doc_session: Session for database access

    Examples:
        >>> from ndi.session import SessionDir
        >>> session = SessionDir('/path/to/session')
        >>> calc = Calculator(session, 'my_calc_type', 'path/to/doc.json')
    """

    def __init__(self, session: Optional[Any] = None,
                 document_type: str = '',
                 path_to_doc_type: str = ''):
        """
        Create an ndi.calculator object.

        Args:
            session: The ndi.session object to operate on
            document_type: The document type for this calculator
            path_to_doc_type: Path to the document type definition

        Examples:
            >>> calc = Calculator(session, 'simple_calc', 'path/to/simple_calc.json')
        """
        # Initialize App
        App.__init__(self, session)

        # Initialize AppDoc
        doc_types = [document_type] if document_type else []
        doc_document_types = [path_to_doc_type] if path_to_doc_type else []
        AppDoc.__init__(self, doc_types, doc_document_types, session)

        # Set name to class name
        self.name = self.__class__.__name__

    def run(self, doc_exists_action: str = 'NoAction',
            parameters: Optional[Dict[str, Any]] = None) -> List[Any]:
        """
        Run calculator on all possible inputs matching parameters.

        Args:
            doc_exists_action: Action to take if document exists:
                - 'Error': Raise error if document exists
                - 'NoAction': Skip if document exists
                - 'Replace': Replace existing documents
                - 'ReplaceIfDifferent': Replace only if different
            parameters: Input parameters (uses defaults if None)

        Returns:
            List of created/found documents

        Examples:
            >>> docs = calc.run('NoAction', parameters)
        """
        logger = logging.getLogger('ndi')

        # Step 1: Set up input parameters
        if parameters is None:
            parameters = self.default_search_for_input_parameters()

        # Step 2: Identify all sets of possible input parameters
        all_parameters = self.search_for_input_parameters(parameters)

        # Step 3: Check for existing calculations and perform as needed
        logger.info(f'Beginning calculator {self.__class__.__name__}...')

        docs = []
        docs_tocat = []

        for i, param_set in enumerate(all_parameters):
            logger.info(f'Performing calculator {i+1} of {len(all_parameters)}.')

            # Check for previous calculations
            previous_calcs = self.search_for_calculator_docs(param_set)
            do_calc = False

            if previous_calcs:
                if doc_exists_action == 'Error':
                    raise ValueError('Doc for input parameters already exists')
                elif doc_exists_action in ['NoAction', 'ReplaceIfDifferent']:
                    docs_tocat.append(previous_calcs)
                    continue  # Skip to next
                elif doc_exists_action == 'Replace':
                    # Remove previous documents
                    self.session.database_rm(previous_calcs)
                    do_calc = True
            else:
                do_calc = True

            if do_calc:
                # Perform calculation
                docs_out = self.calculate(param_set)
                if not isinstance(docs_out, list):
                    docs_out = [docs_out]
                docs_tocat.append(docs_out)

        # Flatten docs_tocat into docs
        for doc_list in docs_tocat:
            if isinstance(doc_list, list):
                docs.extend(doc_list)
            else:
                docs.append(doc_list)

        # Add app properties to all documents
        if docs:
            app_doc = self.newdocument()
            for doc in docs:
                if hasattr(doc, 'setproperties'):
                    doc = doc.setproperties('app', app_doc.document_properties.app)

            # Add to database
            self.session.database_add(docs)

        logger.info('Concluding calculator.')
        return docs

    def default_search_for_input_parameters(self) -> Dict[str, Any]:
        """
        Return default parameters for searching for calculator inputs.

        Returns:
            Dictionary with default search parameters structure:
                - input_parameters: Fixed input parameters
                - depends_on: List of dependency structures

        Examples:
            >>> calc = Calculator(session)
            >>> params = calc.default_search_for_input_parameters()
            >>> 'input_parameters' in params
            True
        """
        return {
            'input_parameters': None,
            'depends_on': []
        }

    def search_for_input_parameters(self,
                                   parameters_specification: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Search for valid inputs to the calculator.

        Identifies all possible sets of specific input parameters that can
        be used as inputs to the calculator.

        Args:
            parameters_specification: Structure with fields:
                - input_parameters: Fixed input parameters
                - depends_on: Specific dependency values
                - query: (optional) Search queries for dependencies

        Returns:
            List of parameter dictionaries, each with:
                - input_parameters: Input parameters for calculation
                - depends_on: List of dependency structures

        Examples:
            >>> params_spec = {'input_parameters': {'threshold': 0.5}, 'depends_on': []}
            >>> all_params = calc.search_for_input_parameters(params_spec)
        """
        fixed_input_parameters = parameters_specification.get('input_parameters')
        fixed_depends_on = parameters_specification.get('depends_on', [])

        # Validate fixed depends_on values
        for dep in fixed_depends_on:
            from .query import Query
            q = Query('base.id', 'exact_string', dep['value'], '')
            results = self.session.database_search(q)
            if len(results) != 1:
                raise ValueError(
                    f'Could not locate document with id {dep["value"]} '
                    f'corresponding to name {dep["name"]}'
                )

        # Get query specification
        if 'query' not in parameters_specification:
            parameters_specification['query'] = self.default_parameters_query(parameters_specification)

        query_spec = parameters_specification.get('query', [])

        if not query_spec:
            # Everything is fixed, return single parameter set
            return [{
                'input_parameters': fixed_input_parameters,
                'depends_on': fixed_depends_on
            }]

        # Search for documents matching queries
        doclist = []
        V = []
        for q_entry in query_spec:
            docs = self.session.database_search(q_entry['query'])
            doclist.append(docs)
            V.append(len(docs))

        # Generate all combinations
        parameters = []
        from itertools import product

        for indices in product(*[range(v) for v in V]):
            is_valid = True
            extra_depends = []

            for i, (q_entry, idx) in enumerate(zip(query_spec, indices)):
                dep = {
                    'name': q_entry['name'],
                    'value': doclist[i][idx].id()
                }
                is_valid = is_valid and self.is_valid_dependency_input(dep['name'], dep['value'])
                extra_depends.append(dep)

                if not is_valid:
                    break

            if is_valid:
                parameters.append({
                    'input_parameters': fixed_input_parameters,
                    'depends_on': fixed_depends_on + extra_depends
                })

        return parameters

    def default_parameters_query(self,
                                parameters_specification: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Return default queries for searching input parameters.

        Args:
            parameters_specification: Parameter specification

        Returns:
            List of query structures with 'name' and 'query' fields

        Examples:
            >>> query = calc.default_parameters_query(params_spec)
        """
        # Base class returns empty query
        return []

    def search_for_calculator_docs(self, parameters: Dict[str, Any]) -> List[Any]:
        """
        Search for previous calculator documents.

        Args:
            parameters: Parameter structure with:
                - input_parameters: Input parameters
                - depends_on: Dependency structures

        Returns:
            List of matching calculator documents

        Examples:
            >>> docs = calc.search_for_calculator_docs(parameters)
        """
        if not self.doc_document_types:
            return []

        from .document import Document
        from .query import Query

        # Get document class information
        doc_type = self.doc_document_types[0]
        myemptydoc = Document(doc_type)
        property_list_name = myemptydoc.document_properties.document_class.property_list_name

        # Build query
        q = Query('', 'isa', doc_type, '')

        # Add dependency queries
        if 'depends_on' in parameters:
            for dep in parameters['depends_on']:
                if dep.get('value'):
                    q = q & Query('', 'depends_on', dep['name'], dep['value'])

        # Search database
        docs = self.session.database_search(q)

        # Filter by input_parameters
        matches = []
        for i, doc in enumerate(docs):
            try:
                input_param = getattr(doc.document_properties, property_list_name, {}).get('input_parameters')
            except AttributeError:
                input_param = None

            if self.are_input_parameters_equivalent(input_param, parameters.get('input_parameters')):
                matches.append(i)

        return [docs[i] for i in matches]

    def are_input_parameters_equivalent(self, input_parameters1: Any,
                                       input_parameters2: Any) -> bool:
        """
        Check if two sets of input parameters are equivalent.

        Args:
            input_parameters1: First set of parameters
            input_parameters2: Second set of parameters

        Returns:
            True if equivalent, False otherwise

        Examples:
            >>> calc.are_input_parameters_equivalent(params1, params2)
            True
        """
        # Simple equality check
        return input_parameters1 == input_parameters2

    def is_valid_dependency_input(self, name: str, value: str) -> bool:
        """
        Check if a potential dependency input is valid for this calculator.

        Args:
            name: Dependency name
            value: Document ID value

        Returns:
            True if valid (base class always returns True)

        Examples:
            >>> calc.is_valid_dependency_input('probe_id', 'abc123...')
            True
        """
        return True

    def calculate(self, parameters: Dict[str, Any]) -> Any:
        """
        Perform calculation and generate an ndi document with the answer.

        This is an abstract method that must be overridden in subclasses.

        Args:
            parameters: Parameter structure with:
                - input_parameters: Input parameters for calculation
                - depends_on: Dependency structures

        Returns:
            ndi.document with calculation results (or list of documents)

        Examples:
            >>> doc = calc.calculate(parameters)
        """
        # Base class returns empty - must be overridden
        return []

    def plot(self, doc_or_parameters: Any, **kwargs) -> Dict[str, Any]:
        """
        Provide diagnostic plot to show calculator results.

        Args:
            doc_or_parameters: Document or parameters to plot
            **kwargs: Additional plotting parameters:
                - newfigure: Create new figure (default: False)
                - holdstate: Preserve hold state (default: False)
                - suppress_title: Suppress title (default: False)
                - suppress_x_label: Suppress x label (default: False)
                - suppress_y_label: Suppress y label (default: False)
                - suppress_z_label: Suppress z label (default: False)

        Returns:
            Dictionary with plot handles and metadata

        Examples:
            >>> h = calc.plot(doc, newfigure=True)
        """
        # Base class provides minimal implementation
        # Full plotting will be in Phase 14 (GUI)
        params = {
            'newfigure': kwargs.get('newfigure', False),
            'holdstate': kwargs.get('holdstate', False),
            'suppress_title': kwargs.get('suppress_title', False),
            'suppress_x_label': kwargs.get('suppress_x_label', False),
            'suppress_y_label': kwargs.get('suppress_y_label', False),
            'suppress_z_label': kwargs.get('suppress_z_label', False)
        }

        return {
            'axes': None,
            'figure': None,
            'objects': [],
            'params': params,
            'title': None,
            'xlabel': None,
            'ylabel': None,
            'zlabel': None
        }

    def isequal_appdoc_struct(self, appdoc_type: str, appdoc_struct1: Dict[str, Any],
                             appdoc_struct2: Dict[str, Any]) -> bool:
        """
        Check if two appdoc data structures are equal.

        Args:
            appdoc_type: The type of appdoc
            appdoc_struct1: First structure
            appdoc_struct2: Second structure

        Returns:
            True if equal, False otherwise

        Examples:
            >>> calc.isequal_appdoc_struct('my_type', struct1, struct2)
            True
        """
        # Simple partial match - can be enhanced for nested structures
        if appdoc_struct1 is None and appdoc_struct2 is None:
            return True
        if appdoc_struct1 is None or appdoc_struct2 is None:
            return False

        # Check if struct1 keys are in struct2 with same values
        for key, value in appdoc_struct1.items():
            if key not in appdoc_struct2:
                return False
            if appdoc_struct2[key] != value:
                return False

        return True

    def doc_about(self) -> str:
        """
        Return the about information for this calculator.

        Returns:
            Help/documentation string for this calculator

        Examples:
            >>> text = calc.doc_about()
        """
        # Base class returns class docstring
        return self.__class__.__doc__ or f'Calculator: {self.__class__.__name__}'

    def appdoc_description(self) -> str:
        """
        Return documentation for the document type created by this calculator.

        Returns:
            Documentation string

        Examples:
            >>> desc = calc.appdoc_description()
        """
        return self.doc_about()
