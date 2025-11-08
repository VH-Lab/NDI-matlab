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
%   'recheckFileReport'     - A previous report from this function. If provided,
%                             only the files listed in the 'mismatchedFiles'
%                             field of the report will be re-checked.

    arguments
        D1 (1,1) ndi.dataset
        D2 (1,1) ndi.dataset
        options.verbose (1,1) logical = true
        options.recheckFileReport = []
    end

    report = struct(...
        'documentsInAOnly', {{}}, ...
        'documentsInBOnly', {{}}, ...
        'mismatchedDocuments', struct('id',{}, 'mismatch',{}), ...
        'fileDifferences', struct('documentA_uid',{}, 'documentB_uid',{}, ...
            'documentA_fuid',{}, 'documentA_fname',{}, 'documentB_fuid',{}, 'documentB_fname',{}, ...
            'documentA_size',{}, 'documentB_size',{}, 'documentA_errormsg',{}, 'documentB_errormsg',{}, ...
            'documentDiff',{}) ...
    );

    if ~isempty(options.recheckFileReport)
        if options.verbose
            fprintf('Re-checking %d file differences from the provided report...\n', numel(options.recheckFileReport.fileDifferences));
        end

        file_differences_list = {};

        for i=1:numel(options.recheckFileReport.fileDifferences)
            entry = options.recheckFileReport.fileDifferences(i);

            doc1 = D1.database_search(ndi.query('ndi_document.id', 'exact_string', entry.documentA_uid, ''));
            doc2 = D2.database_search(ndi.query('ndi_document.id', 'exact_string', entry.documentB_uid, ''));

            % THIS IS A SIMPLIFIED RECHECK, ASSUMES DOCS EXIST AND FUIDS ARE CORRECT

            [~,~,~,fuid1] = doc1{1}.is_in_file_list(entry.documentA_fname);
            [~,~,~,fuid2] = doc2{1}.is_in_file_list(entry.documentB_fname);

            file_diff_entry = struct(...
                'documentA_uid', entry.documentA_uid, 'documentB_uid', entry.documentB_uid, ...
                'documentA_fuid', fuid1, 'documentA_fname', entry.documentA_fname, ...
                'documentB_fuid', fuid2, 'documentB_fname', entry.documentB_fname, ...
                'documentA_size', NaN, 'documentB_size', NaN, ...
                'documentA_errormsg', '', 'documentB_errormsg', '', ...
                'documentDiff', '');

            file_obj1 = [];
            file_obj2 = [];
            S1_to_use = [];
            S2_to_use = [];

            is_dataset_session1 = strcmp(doc1{1}.session_id(), D1.id());
            is_dataset_session2 = strcmp(doc2{1}.session_id(), D2.id());

            try
                if is_dataset_session1
                    file_obj1 = D1.database_openbinarydoc(doc1{1}, entry.documentA_fname);
                else
                    S1_to_use = D1.open_session(doc1{1}.session_id());
                    file_obj1 = S1_to_use.database_openbinarydoc(doc1{1}, entry.documentA_fname);
                end
                fseek(file_obj1.fid, 0, 'eof');
                file_diff_entry.documentA_size = ftell(file_obj1.fid);
            catch e
                file_diff_entry.documentA_errormsg = e.message;
            end

            try
                if is_dataset_session2
                    file_obj2 = D2.database_openbinarydoc(doc2{1}, entry.documentB_fname);
                else
                    S2_to_use = D2.open_session(doc2{1}.session_id());
                    file_obj2 = S2_to_use.database_openbinarydoc(doc2{1}, entry.documentB_fname);
                end
                fseek(file_obj2.fid, 0, 'eof');
                file_diff_entry.documentB_size = ftell(file_obj2.fid);
            catch e
                file_diff_entry.documentB_errormsg = e.message;
            end

            if ~isempty(file_obj1) && ~isempty(file_obj2)
                [are_identical, diff_output] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);
                if ~are_identical
                    file_diff_entry.documentDiff = diff_output;
                end
            end

            if ~isempty(file_diff_entry.documentA_errormsg) || ~isempty(file_diff_entry.documentB_errormsg) || ~isempty(file_diff_entry.documentDiff)
                file_differences_list{end+1} = file_diff_entry;
                if options.verbose
                    if ~isempty(file_diff_entry.documentA_errormsg)
                        fprintf('File %s in document %s has an error: %s\n', entry.documentA_fname, doc1{1}.id(), file_diff_entry.documentA_errormsg);
                    end
                    if ~isempty(file_diff_entry.documentB_errormsg)
                        fprintf('File %s in document %s has an error: %s\n', entry.documentB_fname, doc2{1}.id(), file_diff_entry.documentB_errormsg);
                    end
                    if ~isempty(file_diff_entry.documentDiff)
                        fprintf('File %s in document %s has a mismatch.\n', entry.documentA_fname, doc1{1}.id());
                    end
                end
            end

            if ~isempty(file_obj1)
                if is_dataset_session1
                    D1.database_closebinarydoc(file_obj1);
                elseif ~isempty(S1_to_use)
                    S1_to_use.database_closebinarydoc(file_obj1);
                end
            end
            if ~isempty(file_obj2)
                if is_dataset_session2
                    D2.database_closebinarydoc(file_obj2);
                elseif ~isempty(S2_to_use)
                    S2_to_use.database_closebinarydoc(file_obj2);
                end
            end
        end

        if ~isempty(file_differences_list)
            report.fileDifferences = cat(1, file_differences_list{:});
        end
        return;
    end

    d1_docs = D1.database_search(ndi.query('base.id','regexp','(.*)'));
    d2_docs = D2.database_search(ndi.query('base.id','regexp','(.*)'));

    d1_map = containers.Map();
    for i=1:numel(d1_docs)
        d1_map(d1_docs{i}.id()) = d1_docs{i};
    end

    d2_map = containers.Map();
    for i=1:numel(d2_docs)
        d2_map(d2_docs{i}.id()) = d2_docs{i};
    end

    d1_ids = d1_map.keys();
    d2_ids = d2_map.keys();

    report.documentsInAOnly = setdiff(d1_ids, d2_ids);
    report.documentsInBOnly = setdiff(d2_ids, d1_ids);

    common_ids = intersect(d1_ids, d2_ids);

    % Sort common_ids by session_id
    session_ids = cell(numel(common_ids), 1);
    for i=1:numel(common_ids)
        doc = d1_map(common_ids{i});
        session_ids{i} = doc.session_id();
    end
    [~, sort_order] = sort(session_ids);
    common_ids = common_ids(sort_order);

    if options.verbose
        fprintf('Found %d documents in the first dataset and %d documents in the second.\n', numel(d1_ids), numel(d2_ids));
        fprintf('Comparing %d common documents...\n', numel(common_ids));
    end

    mismatched_docs_list = {};
    file_differences_list = {};

    current_S1 = [];
    current_S2 = [];
    current_session_id_1 = '';
    current_session_id_2 = '';

    for i=1:numel(common_ids)
        if options.verbose && mod(i, 500) == 0
            fprintf('...examined %d documents...\n', i);
        end
        doc_id = common_ids{i};
        doc1 = d1_map(doc_id);
        doc2 = d2_map(doc_id);

        if ~strcmp(doc1.session_id(), current_session_id_1)
            current_session_id_1 = doc1.session_id();
            if strcmp(current_session_id_1, D1.id())
                current_S1 = [];
            else
                current_S1 = D1.open_session(current_session_id_1);
            end
        end
        if ~strcmp(doc2.session_id(), current_session_id_2)
            current_session_id_2 = doc2.session_id();
            if strcmp(current_session_id_2, D2.id())
                current_S2 = [];
            else
                current_S2 = D2.open_session(current_session_id_2);
            end
        end

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
        if ~isempty(mismatches)
            mismatched_docs_list{end+1} = struct('id', doc_id, 'mismatch', strjoin(mismatches, ' '));
        end

        fnames1 = doc1.current_file_list();
        fnames2 = doc2.current_file_list();

        all_fnames = union(fnames1, fnames2);

        for f=1:numel(all_fnames)
            fname = all_fnames{f};

            [~, ~, ~, fuid1] = doc1.is_in_file_list(fname);
            [~, ~, ~, fuid2] = doc2.is_in_file_list(fname);

            file_diff_entry = struct(...
                'documentA_uid', doc1.id(), 'documentB_uid', doc2.id(), ...
                'documentA_fuid', fuid1, 'documentA_fname', fname, ...
                'documentB_fuid', fuid2, 'documentB_fname', fname, ...
                'documentA_size', NaN, 'documentB_size', NaN, ...
                'documentA_errormsg', '', 'documentB_errormsg', '', ...
                'documentDiff', '');

            file_obj1 = [];
            file_obj2 = [];

            if isempty(fuid1)
                file_diff_entry.documentA_errormsg = 'not present';
            else
                try
                    if strcmp(doc1.session_id(), D1.id())
                        file_obj1 = D1.database_openbinarydoc(doc1, fname);
                    else
                        file_obj1 = current_S1.database_openbinarydoc(doc1, fname);
                    end
                    fseek(file_obj1.fid, 0, 'eof');
                    file_diff_entry.documentA_size = ftell(file_obj1.fid);
                catch e
                    file_diff_entry.documentA_errormsg = e.message;
                end
            end

            if isempty(fuid2)
                file_diff_entry.documentB_errormsg = 'not present';
            else
                try
                    if strcmp(doc2.session_id(), D2.id())
                        file_obj2 = D2.database_openbinarydoc(doc2, fname);
                    else
                        file_obj2 = current_S2.database_openbinarydoc(doc2, fname);
                    end
                    fseek(file_obj2.fid, 0, 'eof');
                    file_diff_entry.documentB_size = ftell(file_obj2.fid);
                catch e
                    file_diff_entry.documentB_errormsg = e.message;
                end
            end

            if ~isempty(file_obj1) && ~isempty(file_obj2)
                [are_identical, diff_output] = ndi.util.getHexDiffFromFileObj(file_obj1, file_obj2);
                if ~are_identical
                    file_diff_entry.documentDiff = diff_output;
                end
            end

            if ~isempty(file_diff_entry.documentA_errormsg) || ~isempty(file_diff_entry.documentB_errormsg) || ~isempty(file_diff_entry.documentDiff)
                file_differences_list{end+1} = file_diff_entry;
            end

            if ~isempty(file_obj1)
                if strcmp(doc1.session_id(), D1.id())
                    D1.database_closebinarydoc(file_obj1);
                else
                    current_S1.database_closebinarydoc(file_obj1);
                end
            end
            if ~isempty(file_obj2)
                if strcmp(doc2.session_id(), D2.id())
                    D2.database_closebinarydoc(file_obj2);
                else
                    current_S2.database_closebinarydoc(file_obj2);
                end
            end
        end
    end

    if ~isempty(mismatched_docs_list)
        report.mismatchedDocuments = cat(1, mismatched_docs_list{:});
    end
    if ~isempty(file_differences_list)
        report.fileDifferences = cat(1, file_differences_list{:});
    end

end
