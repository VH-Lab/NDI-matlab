function updated_docs_in_target = replaceOldDocs(workingSessionDir, copiedSessionDir)
%REPLACEOLDDOCS - Updates stimulus_presentation docs in a session and its file copy.
%
%   UPDATED_DOCS_IN_TARGET = REPLACEOLDDOCS(WORKINGSESSIONDIR, COPIEDSESSIONDIR)
%
%   Updates 'stimulus_presentation' documents within the NDI session S located at
%   WORKINGSESSIONDIR to conform to the current schema using the
%   ndi.app.stimulus.decoder.parse_stimuli method. It then updates the
%   corresponding documents within a file-based copy of the session's documents
%   located in the COPIEDSESSIONDIR directory.
%
%   COPIEDSESSIONDIR is expected to have the structure created by a function
%   like ndi.fun.dataset.copySessionDocs:
%     COPIEDSESSIONDIR/
%        documents/
%           copied_documents.mat  (contains a cell array, typically named 'modified_docs')
%        files/
%           (binary files associated with the documents)
%
%   Workflow:
%   1. Loads the document list (e.g., 'modified_docs') from the .mat file in COPIEDSESSIONDIR.
%   2. Opens the session S from WORKINGSESSIONDIR.
%   3. Calls ndi.app.stimulus.decoder.parse_stimuli() on S. This automatically
%      removes old 'stimulus_presentation' docs from S's database and adds
%      new ones conforming to the current schema. These new docs have NEW IDs.
%   4. Iterates through the newly created documents ('pdNew') returned by parse_stimuli.
%   5. For each new document, finds the corresponding *original* document in the loaded list
%      ('modified_docs') based on content matching (class, presentation order, epochid).
%   6. If a match is found:
%      a. Copies the 'base' structure (including the *original* document ID) from the
%         matched original document onto the new document.
%      b. **Copies files:** Copies the binary files associated with the *new* document
%         (which are now managed by session S) into the COPIEDSESSIONDIR/files/ directory,
%         using unique names based on the *original* document ID.
%      c. **Updates file references:** Resets the file info on the new document and uses
%         `add_file` to point to the files just copied into COPIEDSESSIONDIR/files/,
%         setting the ingest flag to 0.
%      d. Replaces the original document entry in the 'modified_docs' list with this
%         fully updated document (new content, original ID, correct file refs for the copy).
%   7. Saves the updated 'modified_docs' list back to the .mat file in COPIEDSESSIONDIR,
%      overwriting the original file.
%   8. Returns the updated cell array of documents.
%
%   Inputs:
%       WORKINGSESSIONDIR  - Path to the NDI session directory to be updated.
%       COPIEDSESSIONDIR   - Path to the directory holding the file-based copy.
%
%   Outputs:
%       UPDATED_DOCS_IN_TARGET - The updated cell array of documents that was saved
%                                back to the copied_documents.mat file.
%
%   Example:
%       sessionPath = '/path/to/mySession';
%       backupPath = '/path/to/sessionCopy';
%       % Ensure backupPath exists and has output from copySessionDocs
%       try
%           updated_docs = replaceOldDocs(sessionPath, backupPath);
%           disp('Stimulus presentation documents updated successfully in session and copy.');
%       catch ME
%           disp(['Error during update: ' ME.identifier ' - ' ME.message]);
%       end
%

% --- Setup and Validation ---
arguments
    workingSessionDir (1,1) string {mustBeFolder}
    copiedSessionDir (1,1) string {mustBeFolder} % Needs to exist now
end
workingSessionDir = char(workingSessionDir);
copiedSessionDir = char(copiedSessionDir);

doc_dir = fullfile(copiedSessionDir, 'documents');
files_dir = fullfile(copiedSessionDir, 'files'); % Location for copied files
mat_file_path = fullfile(doc_dir, 'copied_documents.mat');

if ~isfolder(doc_dir)
    error('Copied session directory missing required subfolder: documents');
end
if ~isfolder(files_dir)
     warning('Copied session directory missing subfolder: files. Creating it.');
     mkdir(files_dir);
end
if ~isfile(mat_file_path)
    error(['Required .mat file not found: ' mat_file_path]);
end
disp('Directory structure verified.');

% --- Load Copied Documents ---
disp(['Loading existing copied documents from ' mat_file_path '...']);
variable_name_loaded = 'modified_docs'; % Keep user's original variable name
try
    vars = whos('-file', mat_file_path);
    foundVar = false;
    for v = 1:numel(vars)
        if strcmp(vars(v).name, variable_name_loaded) && strcmp(vars(v).class,'cell')
            loaded_data = load(mat_file_path, variable_name_loaded);
            foundVar = true;
            break;
        end
    end
    if ~foundVar
         error('Could not find cell array variable ''%s'' in %s', variable_name_loaded, mat_file_path);
    end
    docs_in_target = loaded_data.(variable_name_loaded); % Use loaded variable name
catch load_err
    error(['Failed to load data from ' mat_file_path '. Error: ' load_err.message]);
end
disp(['Loaded ' num2str(numel(docs_in_target)) ' documents from target MAT file (' variable_name_loaded ').']);

% --- Open Session ---
disp(['Opening working session from ' workingSessionDir '...']);
S = []; % Initialize S
try
    S = ndi.session.dir(workingSessionDir);
catch session_err
    error('Could not open NDI session at %s. Error: %s', workingSessionDir, session_err.message);
end
disp(['Session ' S.id() ' opened.']);

% --- Find original stim pres docs (for reference later if needed, parse_stimuli will remove them) ---
pD_original_ref = S.database_search(ndi.query('','isa','stimulus_presentation')); % Get originals before parse_stimuli runs
disp(['Found ' num2str(numel(pD_original_ref)) ' original stimulus_presentation documents in S initially.']);

% --- Run parse_stimuli to update docs in Session S ---
disp('Running parse_stimuli to update documents in session S...');
try
    stimulator_probe_search = S.getprobes('type','stimulator'); %
    if numel(stimulator_probe_search) ~= 1
        error('Expected exactly one probe of type ''stimulator'' in session S, found %d.', numel(stimulator_probe_search));
    end
    stimulator_probe = stimulator_probe_search{1}; %

    decode = ndi.app.stimulus.decoder(S); %
    % parse_stimuli with RESET=1 removes old stimpres docs from S and adds new ones
    % pdNew contains the documents newly added to session S
    pdNew = decode.parse_stimuli(stimulator_probe, 1); %
    disp(['parse_stimuli completed, ' num2str(numel(pdNew)) ' new/updated stimulus_presentation documents generated in session S.']);
catch parse_err
    error('Failed to run parse_stimuli on session S. Error: %s', parse_err.message);
end

% --- Update the loaded docs_in_target list ---
disp('Updating document list loaded from target MAT file...');
if isempty(pdNew) && ~isempty(pD_original_ref)
    warning('parse_stimuli did not generate new documents, but originals existed. The target MAT file might be inconsistent.');
    % Decide how to handle this - perhaps remove original stimpres docs from docs_in_target?
    % For now, proceed, but the target file might retain old docs that are gone from S.
elseif ~isempty(pdNew)
    for i=1:numel(pdNew) % Loop through the NEW documents created by parse_stimuli
        match = 0;
        matched_original_doc = [];

        % Find the corresponding OLD document in the loaded list
        for j=1:numel(docs_in_target)
            if isa(docs_in_target{j},'ndi.document') && ...
               strcmp(docs_in_target{j}.doc_class(), pdNew{i}.doc_class()) % Check class name robustly
                % Need robust check for fields before accessing
                has_pres_order_new = isfield(pdNew{i}.document_properties,'stimulus_presentation') && isfield(pdNew{i}.document_properties.stimulus_presentation,'presentation_order');
                has_pres_order_old = isfield(docs_in_target{j}.document_properties,'stimulus_presentation') && isfield(docs_in_target{j}.document_properties.stimulus_presentation,'presentation_order');
                has_epochid_new = isfield(pdNew{i}.document_properties,'epochid') && isfield(pdNew{i}.document_properties.epochid,'epochid');
                has_epochid_old = isfield(docs_in_target{j}.document_properties,'epochid') && isfield(docs_in_target{j}.document_properties.epochid,'epochid');

                if has_pres_order_new && has_pres_order_old && has_epochid_new && has_epochid_old
                    if isequal(pdNew{i}.document_properties.stimulus_presentation.presentation_order,...
                               docs_in_target{j}.document_properties.stimulus_presentation.presentation_order)
                        if strcmp(pdNew{i}.document_properties.epochid.epochid,...
                                  docs_in_target{j}.document_properties.epochid.epochid)
                            match = j;
                            matched_original_doc = docs_in_target{j}; % Keep the original doc reference
                            break;
                        end
                    end
                end
            end
        end % loop j

        if match > 0
            disp(['Found match for new doc epoch ' pdNew{i}.document_properties.epochid.epochid ' at target index ' int2str(match) '. Updating...']);

            original_base_struct = matched_original_doc.document_properties.base;
            original_doc_id = original_base_struct.id; % ID of the document being replaced

            pdNew_ID = pdNew{i}.document_properties.base.id;

            % 1. Preserve the original base (including ID)
            pdNew{i} = pdNew{i}.setproperties('base', original_base_struct); % Force original ID onto new content

            % 2. Copy files associated with pdNew{i} from session S to target/files

            current_doc_id = pdNew{i}.id(); % Should be the original ID now
            file_list = pdNew{i}.current_file_list(); % Files associated with the NEW content
            file_params_to_add = {};

            if ~isempty(file_list)
                 disp(['  Copying ' num2str(numel(file_list)) ' files from session S for doc ' current_doc_id '...']);
                 for k = 1:numel(file_list)
                     fname = file_list{k};
                     % Get source path from S database (for the doc with current_doc_id)
                     [tf, src_path] = S.database_existbinarydoc(pdNew_ID, fname); %

                     if tf && isfile(src_path)
                         safe_fname_part = matlab.lang.makeValidName(fname);
                         % Use ORIGINAL ID for unique filename, as requested by user logic
                         unique_dest_fname = [current_doc_id '__' safe_fname_part];
                         dest_path = fullfile(files_dir, unique_dest_fname);
                         try
                             if ~isfile(dest_path)
                                 copyfile(src_path, dest_path);
                                 disp(['    Copied file ' fname ' to ' dest_path]);
                             else
                                 disp(['    File ' dest_path ' already exists. Skipping copy.']);
                             end
                             % Store params to add file reference to the copied doc
                             file_params_to_add{end+1} = {fname, dest_path, 'ingest', 0, 'delete_original', 0}; %
                         catch copy_err
                             error('ndi:replaceOldDocs:FileCopyFailed', ...
                                   'Failed to copy file %s for doc %s from session S to %s. Error: %s', ...
                                   src_path, current_doc_id, dest_path, copy_err.message);
                         end
                     else
                         error('ndi:replaceOldDocs:SourceFileNotFound', ...
                               'Source file %s for doc %s not found in session S database. Cannot copy to target.', ...
                                fname, current_doc_id);
                         % Cannot add this file reference if source missing
                     end
                 end % file list loop
             end % if ~isempty

            % 3. Update file references in pdNew{i} to point to copiedSessionDir/files
            pdNew{i} = pdNew{i}.reset_file_info(); %
            for k=1:numel(file_params_to_add)
                pdNew{i} = pdNew{i}.add_file(file_params_to_add{k}{:}); %
            end

            % 4. Replace entry in the loaded list
            docs_in_target{match} = pdNew{i}; % Replace old doc with the updated new doc (with original ID)
            disp(['  Document at index ' int2str(match) ' updated.']);

        else
            warning(['Could not find matching original document in loaded list for newly parsed document with epochid ' pdNew{i}.document_properties.epochid.epochid '. This document will not be updated in the target .mat file.']);
        end
    end % loop i (pdNew)
end % if ~isempty(pdNew)

% Assign to output variable before saving
updated_docs_in_target = docs_in_target;

% --- Save Updated Docs back to target MAT file ---
disp(['Saving updated document list back to ' mat_file_path '...']);
try
    % Save using the variable name that was loaded
    save_struct.(variable_name_loaded) = updated_docs_in_target;
    save(mat_file_path, '-struct', 'save_struct', '-v7.3');
    disp('Saving complete.');
catch save_err
    error(['Could not save the updated documents to ' mat_file_path '. Error: ' save_err.message]);
end

disp('stimulus_presentation document update process finished.');

end % main function