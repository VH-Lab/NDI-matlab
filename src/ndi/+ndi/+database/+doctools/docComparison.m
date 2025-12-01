classdef docComparison
    % NDI.DATABASE.DOCTOOLS.DOCCOMPARISON - Tools for comparing NDI documents
    %
    % This class allows for the creation of comparison structures to compare
    % NDI documents field by field. It supports various comparison methods
    % and tolerances.
    %
    % Example:
    %    d1 = ndi.document(struct('base',struct('id','1'),'val',10));
    %    dc = ndi.database.doctools.docComparison(d1);
    %    dc = dc.addComparisonParameters('val', 'abs difference', 1);
    %    d2 = ndi.document(struct('base',struct('id','1'),'val',12));
    %    [b, report] = dc.compare(d2, d1);
    %

    properties
        comparisonStruct % Internal structure defining fields and comparison methods
    end

    methods
        function obj = docComparison(input_arg)
            % DOCCOMPARISON - Create a docComparison object
            %
            % OBJ = NDI.DATABASE.DOCTOOLS.DOCCOMPARISON(INPUT_ARG)
            %
            % INPUT_ARG can be:
            %   1) An ndi.document object: The object will be parsed to create
            %      a comparison structure based on its properties.
            %   2) A JSON character array (or string): A JSON representation
            %      of a comparison structure (produced by toJson).
            %   3) (Optional) Empty: Creates an empty object.
            %

            arguments
                input_arg {mustBeA(input_arg, {'ndi.document', 'char', 'string', 'struct'})} = struct([])
            end

            if isempty(input_arg)
                 obj.comparisonStruct = struct('name',{}, 'comparisonMethod', {}, 'toleranceAmount', {});
                 return;
            end

            if isa(input_arg, 'ndi.document')
                 p = input_arg.document_properties;

                 % Remove ignored fields
                 if isfield(p, 'document_class'), p = rmfield(p, 'document_class'); end
                 if isfield(p, 'files'), p = rmfield(p, 'files'); end
                 if isfield(p, 'depends_on'), p = rmfield(p, 'depends_on'); end

                 obj.comparisonStruct = obj.parseStruct(p, '');
            elseif ischar(input_arg) || isstring(input_arg)
                 % JSON input
                 jsonStruct = jsondecode(input_arg);
                 % Ensure it is a struct array with correct fields.
                 % (Assumes valid JSON input for now)
                 obj.comparisonStruct = jsonStruct;
            else
                 % Should not happen given mustBeA, unless user passes struct which is not supported as direct input unless empty
                 error('Input must be an ndi.document or a JSON string.');
            end
        end

        function json_str = toJson(obj)
            % TOJSON - Convert the internal comparison structure to JSON
            %
            % JSON_STR = TOJSON(OBJ)
            %
            % Returns a JSON character array representation of the comparison
            % structure.
            %
            json_str = char(jsonencode(obj.comparisonStruct));
        end

        function obj = addComparisonParameters(obj, scope, comparisonMethod, toleranceAmount)
            % ADDCOMPARISONPARAMETERS - Add or update comparison parameters
            %
            % OBJ = ADDCOMPARISONPARAMETERS(OBJ, SCOPE, COMPARISONMETHOD, TOLERANCEAMOUNT)
            %
            % Update the comparison method and tolerance for fields matching
            % the SCOPE.
            %
            % Inputs:
            %   SCOPE: A string, character array, or cell array of strings
            %          indicating the field names to update.
            %   COMPARISONMETHOD: The method to use. Options:
            %          'none', 'abs difference', 'difference',
            %          'abs percent difference', 'percent difference',
            %          'character exact'.
            %   TOLERANCEAMOUNT: Numeric scalar tolerance.
            %

            arguments
                obj (1,1) ndi.database.doctools.docComparison
                scope {mustBeA(scope, {'char', 'string', 'cell'})}
                comparisonMethod (1,:) char {mustBeMember(comparisonMethod, ...
                    {'none', 'abs difference', 'difference', 'abs percent difference', ...
                     'percent difference', 'character exact'})}
                toleranceAmount (1,1) double
            end

            % Update matches
             for i=1:numel(obj.comparisonStruct)
                 if obj.matchesScope(obj.comparisonStruct(i).name, scope)
                     obj.comparisonStruct(i).comparisonMethod = comparisonMethod;
                     obj.comparisonStruct(i).toleranceAmount = toleranceAmount;
                 end
             end
        end

        function [b, report] = compare(obj, actual, expected)
            % COMPARE - Compare two NDI documents
            %
            % [B, REPORT] = COMPARE(OBJ, ACTUAL, EXPECTED)
            %
            % Compares the ACTUAL document against the EXPECTED document using
            % the stored comparison parameters.
            %
            % Inputs:
            %   ACTUAL: An ndi.document object.
            %   EXPECTED: An ndi.document object.
            %
            % Outputs:
            %   B: Boolean, true if all comparisons pass (within tolerance).
            %   REPORT: A structure array detailing any failures.
            %

            arguments
                obj (1,1) ndi.database.doctools.docComparison
                actual (1,1) ndi.document
                expected (1,1) ndi.document
            end

            b = true;
            report = struct('name', {}, 'actualValue', {}, 'expectedValue', {}, 'comment', {});

            for i=1:numel(obj.comparisonStruct)
                item = obj.comparisonStruct(i);
                if strcmp(item.comparisonMethod, 'none')
                    continue;
                end

                name = item.name;

                % Get values using eval
                try
                    valA = obj.getValue(actual.document_properties, name);
                    valE = obj.getValue(expected.document_properties, name);
                catch
                     % Field missing or error accessing
                     b = false;
                     report(end+1) = struct('name', name, 'actualValue', NaN, 'expectedValue', NaN, 'comment', 'Field missing or error accessing');
                     continue;
                end

                % Perform comparison
                [pass, msg] = obj.performCheck(valA, valE, item.comparisonMethod, item.toleranceAmount);

                if ~pass
                    b = false;
                    report(end+1) = struct('name', name, 'actualValue', valA, 'expectedValue', valE, 'comment', msg);
                end
            end
        end
    end

    methods (Access = private)
        function s = parseStruct(obj, str, prefix)
            s = struct('name', {}, 'comparisonMethod', {}, 'toleranceAmount', {});
            fields = fieldnames(str);
            for i=1:numel(fields)
                f = fields{i};
                val = str.(f);

                if isempty(prefix)
                    currentName = f;
                else
                    currentName = [prefix '.' f];
                end

                if isstruct(val)
                    for k=1:numel(val)
                        if numel(val) > 1
                             subName = [currentName '(' num2str(k) ')'];
                        else
                             subName = currentName;
                        end
                        % Recursively call parseStruct.
                        s = [s obj.parseStruct(val(k), subName)];
                    end
                else
                    entry = struct('name', currentName, 'comparisonMethod', 'none', 'toleranceAmount', 0);
                    s(end+1) = entry;
                end
            end
        end

        function match = matchesScope(obj, name, scope)
             match = false;
             if ischar(scope) || isstring(scope)
                 match = strcmp(name, scope);
             elseif iscell(scope)
                 match = any(strcmp(name, scope));
             end
        end

        function val = getValue(obj, p, name)
            % p is passed in.
            % We evaluate "p.name".
            % Since name can contain "A.B" or "A(1).B", we construct "p.A.B".
            % eval uses 'p' from the current workspace.

            expression = ['p.' name];
            val = eval(expression);
        end

        function [pass, msg] = performCheck(obj, valA, valE, method, tol)
             pass = true; msg = '';

             if strcmp(method, 'character exact')
                 if ~((ischar(valA) || isstring(valA)) && (ischar(valE) || isstring(valE)))
                     pass = false;
                     msg = 'Values are not characters/strings, cannot apply character exact comparison.';
                     return;
                 end
                 if ~strcmp(valA, valE)
                     pass = false;
                     msg = 'Strings do not match exactly.';
                 end
                 return;
             end

             if ~isnumeric(valA) || ~isnumeric(valE)
                 pass = false;
                 msg = 'Values are not numeric, cannot apply comparison method.';
                 return;
             end

             if ~isequal(size(valA), size(valE))
                 pass = false;
                 msg = 'Dimension mismatch between actual and expected values.';
                 return;
             end

             switch method
                 case 'abs difference'
                     diff_val = abs(valA - valE);
                     if any(isnan(diff_val(:)))
                         pass = false;
                         msg = 'Result contains NaN (likely from input NaNs).';
                     elseif any(diff_val(:) > tol)
                         pass = false;
                         msg = sprintf('Abs difference > tolerance %g', tol);
                     end
                 case 'difference'
                     diff_val = valA - valE;
                     if any(isnan(diff_val(:)))
                         pass = false;
                         msg = 'Result contains NaN (likely from input NaNs).';
                     elseif any(diff_val(:) > tol)
                         pass = false;
                         msg = sprintf('Difference > tolerance %g', tol);
                     end
                 case 'abs percent difference'
                     denom = valE;
                     mask = denom == 0;

                     diff_val = abs((valA - valE) ./ valE) * 100;

                     if any(mask(:))
                         diff_val(mask) = Inf;
                         bothZero = (valA == 0) & (valE == 0);
                         diff_val(bothZero) = 0;
                     end

                     if any(isnan(diff_val(:)))
                         pass = false;
                         msg = 'Result contains NaN (likely from input NaNs).';
                     elseif any(diff_val(:) > tol)
                         pass = false;
                         msg = sprintf('Abs percent difference > tolerance %g%%', tol);
                     end
                 case 'percent difference'
                     denom = valE;
                     mask = denom == 0;
                     diff_val = ((valA - valE) ./ valE) * 100;

                     if any(mask(:))
                         diff_val(mask) = Inf;
                         bothZero = (valA == 0) & (valE == 0);
                         diff_val(bothZero) = 0;
                     end

                     if any(isnan(diff_val(:)))
                         pass = false;
                         msg = 'Result contains NaN (likely from input NaNs).';
                     elseif any(diff_val(:) > tol)
                         pass = false;
                         msg = sprintf('Percent difference > tolerance %g%%', tol);
                     end
                 otherwise
                     pass = false;
                     msg = ['Unknown comparison method: ' method];
             end
        end
    end
end
