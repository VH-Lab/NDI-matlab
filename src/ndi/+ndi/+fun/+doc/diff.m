function [are_equal, report] = diff(doc1, doc2, options)
% DIFF - Compare two NDI documents for equality.
%
%   [ARE_EQUAL, REPORT] = ndi.fun.doc.diff(DOC1, DOC2, 'ignoreFields', {'base.session_id'}, 'checkFiles', true)
%
%   Compares two NDI documents (DOC1, DOC2) and determines if they are equal
%   in content. This comparison is more robust than simple equality checks as
%   it handles:
%   1. Order-independent comparison of 'depends_on' fields.
%   2. Order-independent comparison of file lists (if 'checkFiles' is true).
%   3. Exclusion of specific fields (like 'base.session_id').
%
%   Inputs:
%   DOC1, DOC2 - ndi.document objects to compare.
%
%   Outputs:
%   ARE_EQUAL - Logical true if documents match, false otherwise.
%   REPORT    - A structure detailing the differences. Fields:
%               'mismatch' - Boolean indicating mismatch.
%               'details'  - Cell array of strings describing differences.
%
%   Options:
%   'ignoreFields' - Cell array of strings specifying fields to ignore in the
%                    comparison. Default: {'base.session_id'}.
%                    Fields can be nested using dot notation (e.g., 'base.id').
%   'checkFiles'   - Logical. If true (default), checks if the file lists
%                    in the 'files' property contain the same file names.
%                    It does NOT compare the binary content of the files.

    arguments
        doc1 (1,1) ndi.document
        doc2 (1,1) ndi.document
        options.ignoreFields (1,:) cell = {'base.session_id'}
        options.checkFiles (1,1) logical = true
    end

    are_equal = true;
    report = struct('mismatch', false, 'details', {{}});
    details = {};

    props1 = doc1.document_properties;
    props2 = doc2.document_properties;

    % 1. Remove ignored fields
    for i = 1:numel(options.ignoreFields)
        field = options.ignoreFields{i};
        parts = strsplit(field, '.');
        if numel(parts) == 1
            if isfield(props1, field), props1 = rmfield(props1, field); end
            if isfield(props2, field), props2 = rmfield(props2, field); end
        elseif numel(parts) == 2
            if isfield(props1, parts{1}) && isfield(props1.(parts{1}), parts{2})
                props1.(parts{1}) = rmfield(props1.(parts{1}), parts{2});
            end
            if isfield(props2, parts{1}) && isfield(props2.(parts{1}), parts{2})
                props2.(parts{1}) = rmfield(props2.(parts{1}), parts{2});
            end
        end
    end

    % 2. Handle 'depends_on' (Order Independent)
    dep1 = [];
    dep2 = [];
    if isfield(props1, 'depends_on')
        dep1 = props1.depends_on;
        props1 = rmfield(props1, 'depends_on');
    end
    if isfield(props2, 'depends_on')
        dep2 = props2.depends_on;
        props2 = rmfield(props2, 'depends_on');
    end

    if ~isempty(dep1) || ~isempty(dep2)
        if numel(dep1) ~= numel(dep2)
            are_equal = false;
            details{end+1} = sprintf('Number of dependencies differs: %d vs %d.', numel(dep1), numel(dep2));
        else
            % Sort by name
            [~, idx1] = sort({dep1.name});
            dep1 = dep1(idx1);
            [~, idx2] = sort({dep2.name});
            dep2 = dep2(idx2);

            if ~isequal(dep1, dep2)
                are_equal = false;
                details{end+1} = 'Dependencies do not match.';
            end
        end
    end

    % 3. Handle 'files' (Order Independent List Check)
    files1 = [];
    files2 = [];
    if isfield(props1, 'files')
        files1 = props1.files;
        props1 = rmfield(props1, 'files');
    end
    if isfield(props2, 'files')
        files2 = props2.files;
        props2 = rmfield(props2, 'files');
    end

    if options.checkFiles
        fList1 = {};
        fList2 = {};

        if isfield(files1, 'file_list'), fList1 = files1.file_list; end
        if isfield(files2, 'file_list'), fList2 = files2.file_list; end

        % Ensure column vectors for consistancy
        fList1 = sort(fList1(:));
        fList2 = sort(fList2(:));

        if ~isequal(fList1, fList2)
            are_equal = false;
            details{end+1} = 'File lists do not match.';
        end
    end

    % 4. Compare remaining properties
    if ~isequaln(props1, props2)
        are_equal = false;
        details{end+1} = 'Document properties do not match.';
    end

    report.mismatch = ~are_equal;
    report.details = details;

end
