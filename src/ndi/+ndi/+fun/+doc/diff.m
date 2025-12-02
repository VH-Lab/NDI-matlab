function [are_equal, report] = diff(doc1, doc2, options)
% DIFF - Compare two NDI documents for equality.
%
%   [ARE_EQUAL, REPORT] = ndi.fun.doc.diff(DOC1, DOC2, 'ignoreFields', {'base.session_id'}, 'checkFileList', true, 'checkFiles', false, 'session1', [], 'session2', [])
%
%   Compares two NDI documents (DOC1, DOC2) and determines if they are equal
%   in content. This comparison is more robust than simple equality checks as
%   it handles:
%   1. Order-independent comparison of 'depends_on' fields.
%   2. Order-independent comparison of file lists (if 'checkFileList' is true).
%   3. Exclusion of specific fields (like 'base.session_id').
%   4. Binary comparison of files (if 'checkFiles' is true).
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
%   'checkFileList'- Logical. If true (default), checks if the file lists
%                    in the 'files' property contain the same file names.
%   'checkFiles'   - Logical. If true (default false), checks if the binary content
%                    of the files matches. If true, session1 and session2 MUST be provided.
%   'session1'     - ndi.session object for doc1. Required if checkFiles is true.
%   'session2'     - ndi.session object for doc2. Required if checkFiles is true.

    arguments
        doc1 (1,1) ndi.document
        doc2 (1,1) ndi.document
        options.ignoreFields (1,:) cell = {'base.session_id'}
        options.checkFileList (1,1) logical = true
        options.checkFiles (1,1) logical = false
        options.session1
        options.session2
    end

    if options.checkFiles
        if ~isfield(options, 'session1') || isempty(options.session1) || ~isfield(options, 'session2') || isempty(options.session2)
            error('If checkFiles is true, session1 and session2 must be provided.');
        end
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

    if options.checkFileList
        fList1 = {};
        fList2 = {};

        if isfield(files1, 'file_list'), fList1 = files1.file_list; end
        if isfield(files2, 'file_list'), fList2 = files2.file_list; end

        % Ensure column vectors for consistency
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

    % 5. Check binary file content if requested
    if options.checkFiles
        fList1 = doc1.current_file_list();
        fList2 = doc2.current_file_list();
        all_fnames = union(fList1, fList2);

        for f = 1:numel(all_fnames)
            fname = all_fnames{f};

            % Check presence in both docs
            [in1, ~, ~, fuid1] = doc1.is_in_file_list(fname);
            [in2, ~, ~, fuid2] = doc2.is_in_file_list(fname);

            if in1 ~= in2
                are_equal = false;
                if in1
                    details{end+1} = sprintf('File %s present in doc1 but not doc2.', fname);
                else
                    details{end+1} = sprintf('File %s present in doc2 but not doc1.', fname);
                end
                continue; % Cannot compare content if not in both
            end

            % Compare content
            if in1 && in2
                file_obj1 = [];
                file_obj2 = [];
                try
                    file_obj1 = options.session1.database_openbinarydoc(doc1, fname);
                    fseek(file_obj1.fid, 0, 'eof');
                    size1 = ftell(file_obj1.fid);
                    fseek(file_obj1.fid, 0, 'bof'); % Rewind

                    file_obj2 = options.session2.database_openbinarydoc(doc2, fname);
                    fseek(file_obj2.fid, 0, 'eof');
                    size2 = ftell(file_obj2.fid);
                    fseek(file_obj2.fid, 0, 'bof'); % Rewind

                    if size1 ~= size2
                        are_equal = false;
                        details{end+1} = sprintf('File %s size mismatch: %d vs %d.', fname, size1, size2);
                    else
                        [are_identical, diff_output] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);
                        if ~are_identical
                            are_equal = false;
                            details{end+1} = sprintf('File %s content mismatch.', fname);
                        end
                    end
                catch e
                    are_equal = false;
                    details{end+1} = sprintf('Error comparing file %s: %s', fname, e.message);
                end

                if ~isempty(file_obj1), options.session1.database_closebinarydoc(file_obj1); end
                if ~isempty(file_obj2), options.session2.database_closebinarydoc(file_obj2); end
            end
        end
    end

    report.mismatch = ~are_equal;
    report.details = details;

end
