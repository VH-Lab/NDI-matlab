function [B, MSG] = sessionDiff(S1, S2)
%SESSIONDIFF - Compares two NDI sessions for differences in documents and files.
%
%   [B, MSG] = SESSIONDIFF(S1, S2)
%
%   Compares two ndi.session objects, S1 and S2, to identify differences
%   in their contained documents and associated binary file content.
%
%   The comparison checks:
%   1. If documents with the same ID exist in both sessions.
%   2. If documents with the same ID have identical metadata properties
%      (excluding the 'files' structure, as file paths will differ).
%   3. If documents with the same ID have the same list of associated files (by name).
%   4. If the content of associated files with the same logical name and same
%      document ID is identical between the two sessions.
%
%   Inputs:
%       S1     - The first ndi.session object to compare.
%       S2     - The second ndi.session object to compare.
%
%   Outputs:
%       B      - Boolean. True if sessions are identical in terms of the
%                checked documents and files, False otherwise.
%       MSG    - Cell array of strings. Contains messages detailing differences
%                found, or {'Sessions S1 and S2 have identical document metadata (excluding file info) and identical file content.'} if B is true.
%
%   Example:
%       sessionA = ndi.session.dir('/path/to/sessionA');
%       sessionB = ndi.session.dir('/path/to/sessionB');
%       [areIdentical, diffMessages] = ndi.fun.dataset.sessionDiff(sessionA, sessionB);
%       if areIdentical
%           disp('Session A and Session B appear identical.');
%       else
%           disp('Differences found between Session A and Session B:');
%           disp(diffMessages);
%       end
%

% --- Input Validation ---
arguments
    S1 (1,1) {mustBeA(S1, ["ndi.session","ndi.dataset"])} % Allow dataset comparison too
    S2 (1,1) {mustBeA(S2, ["ndi.session","ndi.dataset"])} % Allow dataset comparison too
end

% --- Initial Setup ---
B = true; % Assume success initially
MSG = {};
chunkSize = 1024*1024; % 1MB chunk size for file comparison

disp('Starting session comparison...');

% --- Search Documents in Both Sessions ---
disp('Searching for documents in S1...');
try
    docs1 = S1.database_search(ndi.query('','isa','base')); %
catch search_err1
    MSG{end+1} = ['Failed to search S1. Error: ' search_err1.message];
    B = false;
    return;
end
disp(['Found ' num2str(numel(docs1)) ' documents in S1.']);

disp('Searching for documents in S2...');
try
    docs2 = S2.database_search(ndi.query('','isa','base')); %
catch search_err2
    MSG{end+1} = ['Failed to search S2. Error: ' search_err2.message];
    B = false;
    return;
end
disp(['Found ' num2str(numel(docs2)) ' documents in S2.']);

% --- Compare Document Counts (Informational) ---
if numel(docs1) ~= numel(docs2)
    msg_str = ['Warning: Different number of documents found. S1=' num2str(numel(docs1)) ...
               ', S2=' num2str(numel(docs2)) '. Proceeding to compare by ID.'];
    MSG{end+1} = msg_str;
    disp(msg_str);
    % B = false; % Don't set B to false yet, base comparison on IDs
end

% --- Build ID Maps for Efficient Lookup ---
map1_id_to_index = containers.Map('KeyType','char','ValueType','any'); % Use 'any' for index or error flag
for i=1:numel(docs1)
    if isa(docs1{i},'ndi.document')
        map1_id_to_index(docs1{i}.id()) = i;
    else
         warning('Item %d in S1 docs is not an ndi.document.', i);
    end
end
map2_id_to_index = containers.Map('KeyType','char','ValueType','any');
for i=1:numel(docs2)
    if isa(docs2{i},'ndi.document')
        map2_id_to_index(docs2{i}.id()) = i;
     else
         warning('Item %d in S2 docs is not an ndi.document.', i);
     end
end

% --- Compare Documents and Files from S1's perspective ---
disp('Comparing documents present in S1...');
ids1 = map1_id_to_index.keys;

for i = 1:numel(ids1)
    doc1_id = ids1{i};
    doc1_idx = map1_id_to_index(doc1_id);
    doc1 = docs1{doc1_idx};

    disp(['Comparing document ' num2str(i) '/' num2str(numel(ids1)) ': ID ' doc1_id]);

    if ~map2_id_to_index.isKey(doc1_id)
        MSG{end+1} = ['Document ID ' doc1_id ' exists in S1 but not in S2.'];
        B = false;
        continue; % Check next document in S1
    end

    % Document exists in both, proceed with comparison
    doc2_idx = map2_id_to_index(doc1_id);
    doc2 = docs2{doc2_idx};

    % --- a) Compare Document Metadata (excluding files structure) ---
    try
        props1 = doc1.document_properties;
        props2 = doc2.document_properties;

        % Remove the 'files' structure before comparison
        if isfield(props1,'files')
             props1 = rmfield(props1,'files');
        end
        if isfield(props2,'files')
             props2 = rmfield(props2,'files');
        end

        % Use isequaln for robust comparison (handles NaNs, struct order)
        % This comparison INCLUDES base.session_id and base.datestamp
        if ~isequaln(props1, props2)
            msg_str = ['Document properties differ for ID ' doc1_id];
            MSG{end+1} = msg_str;
            disp(['  ' msg_str]);
            B = false;
            % Optional: Add more detail
            % diff_details = vlt.data.structwhatsdiff(props1, props2);
            % MSG{end} = [MSG{end} ': ' jsonencode(diff_details)];
        else
            disp('  Metadata matches.');
        end
    catch meta_err
        msg_str = ['Error comparing metadata for document ID ' doc1_id ': ' meta_err.message];
        MSG{end+1} = msg_str;
        disp(['  ' msg_str]);
        B = false;
    end

    % --- b) Compare File Lists and Contents ---
    try
        file_list1 = doc1.current_file_list(); %
        file_list2 = doc2.current_file_list(); %

        if ~isequal(sort(file_list1), sort(file_list2))
            msg_str = ['File lists differ for document ID ' doc1_id];
            MSG{end+1} = msg_str;
            disp(['  ' msg_str]);
            B = false;
        else
            % File lists match (by name), now compare content
            if ~isempty(file_list1)
                disp(['  Comparing ' num2str(numel(file_list1)) ' files for doc ' doc1_id '...']);
                for k = 1:numel(file_list1)
                    fname = file_list1{k}; % Logical name
                    disp(['    Comparing file: ' fname]);

                    binDoc1 = []; % Handle for S1 binary doc
                    binDoc2 = []; % Handle for S2 binary doc

                    try
                        % Open file from S1 via database
                        binDoc1 = S1.database_openbinarydoc(doc1_id, fname); %
                        if isempty(binDoc1)
                            error('Could not open binary document %s from S1.', fname);
                        end

                        % Open file from S2 via database
                        binDoc2 = S2.database_openbinarydoc(doc1_id, fname); % Use same ID
                        if isempty(binDoc2)
                            error('Could not open binary document %s from S2.', fname);
                        end

                        % Compare content chunk by chunk
                        content_match = true; % Assume match until proven otherwise
                        while (true) % Loop until break
                            data1 = binDoc1.fread(chunkSize, '*uint8'); %
                            data2 = binDoc2.fread(chunkSize, '*uint8'); %

                            eof1 = binDoc1.feof(); %
                            eof2 = binDoc2.feof(); %

                            if ~isequal(data1, data2)
                                msg_str = ['Content mismatch for file ' fname ' in document ID ' doc1_id];
                                MSG{end+1} = msg_str;
                                disp(['      ' msg_str]);
                                B = false;
                                content_match = false;
                                break; % Exit inner while loop
                            end

                            if eof1 ~= eof2
                                msg_str = ['EOF status mismatch for file ' fname ' in document ID ' doc1_id];
                                MSG{end+1} = msg_str;
                                disp(['      ' msg_str]);
                                B = false;
                                content_match = false;
                                break; % Exit inner while loop
                            end

                            if eof1 % If both are EOF (since status matches), we are done comparing this file
                                break; % Exit inner while loop
                            end
                        end % while true (chunk comparison)

                        if content_match
                             disp('      Content matches.');
                        end


                    catch file_err % Catch errors during file open/read/compare
                        msg_str = ['Error comparing file ' fname ' for document ID ' doc1_id ': ' file_err.message];
                        MSG{end+1} = msg_str;
                        disp(['      ' msg_str]);
                        B = false;
                    end % try/catch for file processing

                    % Cleanup: Close files within the loop for each file
                    if ~isempty(binDoc1)
                        try S1.database_closebinarydoc(binDoc1); catch, end; % Close quietly
                    end
                    if ~isempty(binDoc2)
                        try S2.database_closebinarydoc(binDoc2); catch, end; % Close quietly
                    end

                    if ~B % If a file comparison failed, stop comparing files for this doc
                         break;
                    end

                end % loop k (files)
            else
                 disp('  No files associated with this document in either session.');
            end % if ~isempty(file_list1)
        end % file list check
    catch file_list_err
         msg_str = ['Error processing file list for document ID ' doc1_id ': ' file_list_err.message];
         MSG{end+1} = msg_str;
         disp(['  ' msg_str]);
         B = false;
    end % try/catch for file list/content

end % loop i (S1 documents)

% --- Check for Documents Only in S2 ---
disp('Checking for documents present only in S2...');
ids2 = map2_id_to_index.keys;
found_s2_only = false;
for i = 1:numel(ids2)
    if ~map1_id_to_index.isKey(ids2{i})
        msg_str = ['Document ID ' ids2{i} ' exists in S2 but not in S1.'];
        MSG{end+1} = msg_str;
        disp(['  ' msg_str]);
        B = false;
        found_s2_only = true;
    end
end
if ~found_s2_only
    disp('  No documents found only in S2.');
end

% --- Final Result ---
if B
    final_msg = 'Sessions S1 and S2 have identical document metadata (excluding file info) and identical file content.';
    MSG = {final_msg};
    disp(final_msg);
else
    disp('Comparison finished: Differences found. See MSG output for details.');
end

end % main function