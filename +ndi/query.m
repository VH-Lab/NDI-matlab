% Ensure the did.query class definition is available on the MATLAB path

classdef query < did.query
% ndi.query: search an ndi.database for ndi.documents (inherits from did.query)
%
% ndi.query objects define searches for ndi.documents; they are passed to the ndi.database/search function.
% This class inherits functionality directly from did.query, providing the same methods
% for constructing and combining search criteria, but within the NDI namespace.
%
% ndi.query Properties (Inherited from did.query):
%   searchstructure - a structure with fields 'field','operation','param1','param2' that describe the search
%
% ndi.query Methods (Inherited from did.query):
%   query - The creator (constructor) documented below.
%   and - Combine two queries into a single query; search for A AND B
%   or - Create a query that searches for A OR B
%   to_searchstructure - Convert an ndi.query into a structure suitable for lower-level search functions.
%   searchstruct - (Static) make a search structure from field, operation, param1, param2 inputs
%   searchcellarray2searchstructure - (Static) convert a search cell array to a search structure
%
% Examples:
%   q = ndi.query('ndi_document_property.id','exact_string','12345678','')
%   q = ndi.query('ndi_document_property.name','exact_string','my_ndi_name','')
%   q = ndi.query('ndi_document_property.name','regexp','(.*)') % match any name
%   q = ndi.query('','isa','ndi.document.base') % match any document of class ndi.document.base or its subclasses
%
% See also: did.query, ndi.query/query, did.database/search

    methods
        function ndi_query_obj = query(field,op,param1,param2)
            % QUERY - create an NDI query object for searching an NDI database
            %
            % Creates an NDI.QUERY object, which inherits from DID.QUERY.
            % It encapsulates search criteria in a SEARCHSTRUCTURE property
            % appropriate for use with FIELDSEARCH or similar functions used
            % by the NDI database search mechanism.
            %
            % The SEARCHSTRUCTURE has the fields:
            % Field:                   | Description
            % ---------------------------------------------------------------------------
            % field                      | A character string of the field to examine (e.g., 'ndi_document_property.name')
            % operation                  | The operation to perform. Most operations can be
            %                            |   negated by prefixing with '~'. This operation
            %                            |   determines values of fields 'param1' and 'param2'.
            %     |----------------------|----------------------------------------------------
            %     |   'regexp'             - Regular expression match between field value and 'param1'.
            %     |   'exact_string'       - Field value is an exact string match for 'param1'.
            %     |   'contains_string'    - Field value is a char array that contains 'param1'.
            %     |   'exact_number'       - Field value is exactly 'param1' (same size and values).
            %     |   'lessthan'           - Field value is less than 'param1'.
            %     |   'lessthaneq'         - Field value is less than or equal to 'param1'.
            %     |   'greaterthan'        - Field value is greater than 'param1'.
            %     |   'greaterthaneq'      - Field value is greater than or equal to 'param1'.
            %     |   'hasfield'           - Field is present? (no role for 'param1'/'param2').
            %     |   'hasanysubfield_contains_string' - Field is struct/cell array where any element
            %     |                                    has subfield 'param1' containing string 'param2'.
            %     |   'isa'                - Document class is or inherits from 'param1'.
            %     |   'depends_on'         - Document depends on item with name 'param1' and value 'param2'.
            %     |   'or'                 - Logical OR of search structures in 'param1' and 'param2'.
            %     |   '~...'               - Negation of most operations above (e.g., '~exact_number').
            %     |----------------------|----------------------------------------------------
            % param1                     | Search parameter 1. Meaning depends on 'operation' (see above).
            % param2                     | Search parameter 2. Meaning depends on 'operation' (see above).
            % ---------------------------------------------------------------------------
            % See FIELDSEARCH documentation for full details of the search structure.
            %
            % Construction options are identical to did.query:
            %
            % NDI_QUERY_OBJ = NDI.QUERY(SEARCHSTRUCT) - Accepts a SEARCHSTRUCT.
            % NDI_QUERY_OBJ = NDI.QUERY(SEARCHCELLARRAY) - Accepts {'prop1',val1,...}.
            % NDI_QUERY_OBJ = NDI.QUERY(FIELD, OPERATION, PARAM1, PARAM2) - Specifies components.
            %
            % Examples:
            %   q = ndi.query('ndi_document_property.id','exact_string','12345678','')
            %   q = ndi.query('ndi_document_property.name','exact_string','my_ndi_name')
            %   q = ndi.query('ndi_document_property.name','regexp','(.*)') % match any name
            %   q = ndi.query('','isa','ndi.document.base') % match any ndi.document.base or subclass

            % Argument block identical to did.query to ensure consistent interface
            arguments
                field % Type checking depends on nargin, handled by superclass
                % Operation is required if nargin >= 2, must be member of valid list
                op (1,:) {mustBeMember(op, {'regexp', 'exact_string', 'contains_string', ...
                                           'exact_number', 'lessthan', 'lessthaneq', ...
                                           'greaterthan', 'greaterthaneq', 'hasfield', ...
                                           'hasanysubfield_contains_string', 'isa', 'depends_on', ...
                                           'or', ... % Keep 'or' (cannot be negated)
                                           '~regexp', '~exact_string', '~contains_string', ...
                                           '~exact_number', '~lessthan', '~lessthaneq', ...
                                           '~greaterthan', '~greaterthaneq', '~hasfield', ...
                                           '~hasanysubfield_contains_string', '~isa', '~depends_on'})} = 'hasfield';
                param1 = '' % Optional, defaults handled by MATLAB if omitted
                param2 = '' % Optional, defaults handled by MATLAB if omitted
            end

            % Call the superclass constructor (did.query)
            % Pass only the arguments that were actually provided to this
            % constructor function call, thereby preserving the nargin-based
            % logic within the did.query constructor.
            % nargin here refers to the inputs provided *to this function*.
            inputs = {};
            if nargin>0
                inputs{1} = field;
            end
            if nargin>1
                inputs{2} = op;
            end
            if nargin>2
                inputs{3} = param1;
            end
            if nargin>3
                inputs{4} = param2;
            end;
            ndi_query_obj@did.query(inputs{:});
        end % query() constructor
    end % methods
end % classdef

