function [report] = diff(S1,S2, options)
% DIFF - Compare two sessions for equality and report all differences.
%
%   REPORT = ndi.fun.session.diff(S1, S2, 'verbose', true)
%
%   Compares two NDI sessions (S1, S2) and produces a detailed report of the
%   differences between them. The comparison includes both the documents and the
%   files within the sessions.
%
%   The output REPORT is a structure with the following fields:
%   'documentsInAOnly' - A cell array of NDI document IDs for documents that
%                        exist only in session S1.
%   'documentsInBOnly' - A cell array of NDI document IDs for documents that
%                        exist only in session S2.
%   'mismatchedDocuments' - A structure array detailing documents that are
%                           present in both sessions but have different content.
%                           Each element includes the NDI document ID and a
%                           description of the mismatch.
%   'fileDifferences'     - A structure array detailing files that differ between
%                           the two sessions. Each element includes the file's UID,
%                           the NDI document ID it belongs to, and the output of
%                           ndi.util.hexdiff, which shows the specific
%                           byte-level differences.
%
%   This function also takes name/value pairs that modify its behavior.
%   'verbose'               - Print progress to the command line (default true)
%   'recheckFileReport'     - A previous report from this function. If provided,
%                             only the files listed in the 'fileDifferences'
%                             field of the report will be re-checked.

    arguments
        S1 (1,1) ndi.session
        S2 (1,1) ndi.session
        options.verbose (1,1) logical = true
        options.recheckFileReport = []
    end

    report = struct(...
        'documentsInAOnly', {{}}, ...
        'documentsInBOnly', {{}}, ...
        'mismatchedDocuments', struct('id',{}, 'mismatch',{}), ...
        'fileDifferences', struct('documentA_uid',{}, 'documentB_uid',{}, ...
			'sessionA_id',{}, 'sessionB_id', {}, ...
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

            % Search specifically for these documents.
            % Note: database_search in session enforces session_id check.
            % But here we are rechecking based on IDs from a previous report.
            % The previous report contains document IDs.

            doc1 = S1.database_search(ndi.query('base.id', 'exact_string', entry.documentA_uid, ''));
            doc2 = S2.database_search(ndi.query('base.id', 'exact_string', entry.documentB_uid, ''));

            if isempty(doc1) || isempty(doc2)
                % If doc not found, we can't really recheck file diff properly in the same way,
                % but maybe we should just report error.
                 if options.verbose
                    fprintf('Could not find document(s) for recheck.\n');
                 end
                 continue;
            end

            [~,~,~,fuid1] = doc1{1}.is_in_file_list(entry.documentA_fname);
            [~,~,~,fuid2] = doc2{1}.is_in_file_list(entry.documentB_fname);

            file_diff_entry = struct(...
                'documentA_uid', entry.documentA_uid, 'documentB_uid', entry.documentB_uid, ...
				'sessionA_id', doc1{1}.session_id(), 'sessionB_id', doc2{1}.session_id(), ...
                'documentA_fuid', fuid1, 'documentA_fname', entry.documentA_fname, ...
                'documentB_fuid', fuid2, 'documentB_fname', entry.documentB_fname, ...
                'documentA_size', NaN, 'documentB_size', NaN, ...
                'documentA_errormsg', '', 'documentB_errormsg', '', ...
                'documentDiff', '');

            file_obj1 = [];
            file_obj2 = [];

            try
                file_obj1 = S1.database_openbinarydoc(doc1{1}, entry.documentA_fname);
                fseek(file_obj1.fid, 0, 'eof');
                file_diff_entry.documentA_size = ftell(file_obj1.fid);
            catch e
                file_diff_entry.documentA_errormsg = e.message;
            end

            try
                file_obj2 = S2.database_openbinarydoc(doc2{1}, entry.documentB_fname);
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
                S1.database_closebinarydoc(file_obj1);
            end
            if ~isempty(file_obj2)
                S2.database_closebinarydoc(file_obj2);
            end
        end

        if ~isempty(file_differences_list)
            report.fileDifferences = cat(1, file_differences_list{:});
        end
        return;
    end

    d1_docs = S1.database_search(ndi.query('base.id','regexp','(.*)'));
    d2_docs = S2.database_search(ndi.query('base.id','regexp','(.*)'));

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

    if options.verbose
        fprintf('Found %d documents in the first session and %d documents in the second.\n', numel(d1_ids), numel(d2_ids));
        fprintf('Comparing %d common documents...\n', numel(common_ids));
    end

    mismatched_docs_list = {};
    file_differences_list = {};

    for i=1:numel(common_ids)
        if options.verbose && mod(i, 500) == 0
            fprintf('...examined %d documents...\n', i);
        end
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
				'sessionA_id', doc1.session_id(), 'sessionB_id', doc2.session_id(), ...
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
                    file_obj1 = S1.database_openbinarydoc(doc1, fname);
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
                    file_obj2 = S2.database_openbinarydoc(doc2, fname);
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
                S1.database_closebinarydoc(file_obj1);
            end
            if ~isempty(file_obj2)
                S2.database_closebinarydoc(file_obj2);
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
