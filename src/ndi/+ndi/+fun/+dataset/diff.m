function [report] = diff(D1,D2, options)
% DIFF - Compare two datasets for equality and report all differences.
%
%   REPORT = ndi.fun.dataset.diff(D1, D2, 'verbose', true)
%
%   Compares two NDI datasets (D1, D2) and produces a detailed report of the
%   differences between them. The comparison includes both the documents and the
%   files within the datasets.
%
%   The output REPORT is a structure with the following fields:
%   'documentsInAOnly' - A cell array of NDI document IDs for documents that
%                        exist only in dataset D1.
%   'documentsInBOnly' - A cell array of NDI document IDs for documents that
%                        exist only in dataset D2.
%   'mismatchedDocuments' - A structure array detailing documents that are
%                           present in both datasets but have different content.
%                           Each element includes the NDI document ID and a
%                           description of the mismatch.
%   'mismatchedFiles' - A structure array detailing files that differ between
%                       the two datasets. Each element includes the file's UID,
%                       the NDI document ID it belongs to, and the output of
%                       ndi.util.hexdiff, which shows the specific
%                       byte-level differences.
%   'fileListDifferences' - A structure array detailing differences in file lists
%                           for common documents.
%
%   This function also takes name/value pairs that modify its behavior.
%   'verbose'               - Print progress to the command line (default true)

    arguments
        D1 (1,1) ndi.dataset
        D2 (1,1) ndi.dataset
        options.verbose (1,1) logical = true
    end

    report = struct(...
        'documentsInAOnly', {{}}, ...
        'documentsInBOnly', {{}}, ...
        'mismatchedDocuments', struct('id',{}, 'mismatch',{}), ...
        'mismatchedFiles', struct('uid',{}, 'document_id',{}, 'diff',{}), ...
        'fileListDifferences', struct('id',{},'filesInAOnly',{},'filesInBOnly',{}), ...
        'errors', struct('document_id',{}, 'file_uid',{}, 'message',{}) ...
    );

    d1_docs = D1.database_search(ndi.query('base.id','regexp','(.*)'));
    d2_docs = D2.database_search(ndi.query('base.id','regexp','(.*)'));

    d1_map = containers.Map();
    for i=1:numel(d1_docs)
        d1_map(d1_docs{i}.document_properties.base.id) = d1_docs{i};
    end

    d2_map = containers.Map();
    for i=1:numel(d2_docs)
        d2_map(d2_docs{i}.document_properties.base.id) = d2_docs{i};
    end

    d1_ids = d1_map.keys();
    d2_ids = d2_map.keys();

    report.documentsInAOnly = setdiff(d1_ids, d2_ids);
    report.documentsInBOnly = setdiff(d2_ids, d1_ids);

    common_ids = intersect(d1_ids, d2_ids);

    if options.verbose
        fprintf('Found %d documents in the first dataset and %d documents in the second.\n', numel(d1_ids), numel(d2_ids));
        fprintf('Comparing %d common documents...\n', numel(common_ids));
    end

    mismatched_docs_list = {};
    mismatched_files_list = {};
    file_list_diffs_list = {};
    errors_list = {};

    for i=1:numel(common_ids)
        doc_id = common_ids{i};
        doc1 = d1_map(doc_id);
        doc2 = d2_map(doc_id);

        mismatches = {};

        props1 = doc1.document_properties;
        props2 = doc2.document_properties;

        if isfield(props1, 'files')
            props1 = rmfield(props1, 'files');
        end
        if isfield(props2, 'files')
            props2 = rmfield(props2, 'files');
        end

        if ~isequaln(props1, props2)
            mismatches{end+1} = 'Document properties do not match.';
        end

        f1 = doc1.current_file_list();
        f2 = doc2.current_file_list();

        files_in_A_only = setdiff(f1, f2);
        files_in_B_only = setdiff(f2, f1);

        if ~isempty(files_in_A_only) || ~isempty(files_in_B_only)
            file_list_diffs_list{end+1} = struct('id', doc_id, 'filesInAOnly', {files_in_A_only}, 'filesInBOnly', {files_in_B_only});
        end

        common_files = intersect(f1, f2);

        for f=1:numel(common_files)
            if options.verbose && mod(f, 100) == 0
                fprintf('...examined %d files in document %s...\n', f, doc_id);
            end

            try
                file_obj1 = D1.database_openbinarydoc(doc1, common_files{f});
                cleanup1 = onCleanup(@() D1.database_closebinarydoc(file_obj1));
                data1 = D1.database_readbinarydoc(file_obj1);
            catch e
                errors_list{end+1} = struct('document_id', doc_id, 'file_uid', common_files{f}, 'message', ['Error opening file in dataset 1: ' e.message]);
                continue;
            end

            try
                file_obj2 = D2.database_openbinarydoc(doc2, common_files{f});
                cleanup2 = onCleanup(@() D2.database_closebinarydoc(file_obj2));
                data2 = D2.database_readbinarydoc(file_obj2);
            catch e
                errors_list{end+1} = struct('document_id', doc_id, 'file_uid', common_files{f}, 'message', ['Error opening file in dataset 2: ' e.message]);
                continue;
            end

            [are_identical, diff_output] = ndi.util.getHexDiffFromBytes(data1, data2);

            if ~are_identical
                mismatched_files_list{end+1} = struct('uid', common_files{f}, 'document_id', doc_id, 'diff', diff_output);
            end
        end

        if ~isempty(mismatches)
            mismatched_docs_list{end+1} = struct('id', doc_id, 'mismatch', strjoin(mismatches, ' '));
        end
    end

    if ~isempty(mismatched_docs_list)
        report.mismatchedDocuments = cat(1, mismatched_docs_list{:});
        if options.verbose
            for i=1:numel(mismatched_docs_list)
                fprintf('Document %s has a mismatch: %s\n', mismatched_docs_list{i}.id, mismatched_docs_list{i}.mismatch);
            end
        end
    end

    if ~isempty(errors_list)
        report.errors = cat(1, errors_list{:});
        if options.verbose
            for i=1:numel(errors_list)
                fprintf('Error examining file %s in document %s: %s\n', errors_list{i}.file_uid, errors_list{i}.document_id, errors_list{i}.message);
            end
        end
    end

    if ~isempty(mismatched_files_list)
        report.mismatchedFiles = cat(1, mismatched_files_list{:});
        if options.verbose
            for i=1:numel(mismatched_files_list)
                fprintf('File %s in document %s has a mismatch.\n', mismatched_files_list{i}.uid, mismatched_files_list{i}.document_id);
            end
        end
    end

    if ~isempty(file_list_diffs_list)
        report.fileListDifferences = cat(1, file_list_diffs_list{:});
        if options.verbose
            for i=1:numel(file_list_diffs_list)
                fprintf('File lists for document %s are different.\n', file_list_diffs_list{i}.id);
            end
        end
    end

end
