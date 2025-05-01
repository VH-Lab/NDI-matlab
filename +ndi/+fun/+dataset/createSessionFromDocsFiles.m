function S = createSessionFromDocsFiles(fileDocDir, target)
%CREATESESSIONFROMDOCSFILES - Creates an NDI session from copied documents and files.
%
%   S = CREATESESSIONFROMDOCSFILES(FILEDOCDIR, TARGET)
%
%   Creates a new ndi.session.dir object in the TARGET directory using
%   documents previously processed and saved by a function like
%   ndi.fun.dataset.copySessionDocs into the FILEDOCDIR directory.
%
%   FILEDOCDIR is expected to have the following structure:
%     FILEDOCDIR/
%        documents/
%           copied_documents.mat  (contains 'modified_docs' cell array)
%        files/
%           (binary files associated with the documents)
%
%   ASSUMPTION: The 'modified_docs' loaded from the .mat file are assumed
%   to be correctly prepared for database addition. Specifically, their
%   file references should point to the corresponding files within
%   FILEDOCDIR/files/, and their 'ingest' flags should be set to 1.
%
%   The function performs these steps:
%   1. Validates the input directories and the presence of 'copied_documents.mat'.
%   2. Loads the 'modified_docs' cell array from the .mat file.
%   3. Finds the unique 'session' document within 'modified_docs' and extracts its
%      reference string and original session ID.
%   4. Creates a new ndi.session.dir object at the TARGET path using the extracted
%      reference and the original session ID (using an assumed third constructor argument).
%   5. Updates the session_id for all non-session documents loaded from the .mat file.
%   6. Adds all modified non-session documents to the new session's database in bulk.
%      The database's add method handles copying the files based on the 'ingest' flag.
%   7. Returns the newly created ndi.session.dir object S.
%
%   This function is essentially the inverse of ndi.fun.dataset.copySessionDocs.
%   It is intended to be placed in the +ndi/+fun/+dataset namespace.
%
%   Inputs:
%       FILEDOCDIR - Path to the directory containing the 'documents' and 'files' subdirs.
%       TARGET     - Path where the new ndi.session.dir should be created.
%
%   Outputs:
%       S - The newly created ndi.session.dir object.
%
%   Example:
%       % Assuming '/path/to/backup/session_copy' contains data prepared for recreation
%       source_dir = '/path/to/backup/session_copy';
%       new_session_path = '/path/to/recreated_session';
%       recreatedSession = ndi.fun.dataset.createSessionFromDocsFiles(source_dir, new_session_path);
%       disp(['Recreated NDI session at ' new_session_path]);
%

% --- Input Validation ---
arguments
    fileDocDir (1,1) string {mustBeFolder}              % Source directory must exist
    target (1,1) string {mustBeNonempty}                % Target path must be provided
end
% Convert paths to char vectors
fileDocDir = char(fileDocDir);
target = char(target);

% --- Verify Source Directory Structure ---
disp(['Verifying source directory structure in ' fileDocDir '...']);
doc_dir = fullfile(fileDocDir, 'documents');
files_dir = fullfile(fileDocDir, 'files'); % We check files_dir exists but don't use it directly later
mat_file_path = fullfile(doc_dir, 'copied_documents.mat');

if ~isfolder(doc_dir)
    error('Source directory missing required subfolder: documents');
end
if ~isfolder(files_dir)
    warning('Source directory subfolder ''files'' is missing. Proceeding, but file ingestion will likely fail if documents reference local files.');
    % Continue, maybe documents only reference URLs or have no files
end
if ~isfile(mat_file_path)
    error(['Required .mat file not found: ' mat_file_path]);
end
disp('Source structure verified.');

% --- Load Documents ---
disp(['Loading documents from ' mat_file_path '...']);
try
    loaded_data = load(mat_file_path, 'modified_docs');
catch load_err
    error(['Failed to load data from ' mat_file_path '. Error: ' load_err.message]);
end

if ~isfield(loaded_data, 'modified_docs')
    error(['The .mat file ' mat_file_path ' does not contain the expected variable ''modified_docs''.']);
end
if ~iscell(loaded_data.modified_docs)
     error('Variable ''modified_docs'' in .mat file must be a cell array.');
end
loaded_docs = loaded_data.modified_docs; % Rename for clarity
disp(['Loaded ' num2str(numel(loaded_docs)) ' documents.']);

if isempty(loaded_docs)
    error('No documents found in the loaded .mat file. Cannot create session.');
end

% --- Find Session Document and Extract Reference and ID ---
disp('Finding session document, reference, and original ID...');
session_ref_name = '';
original_session_id = ''; % Variable to store the original session ID
session_doc_count = 0;
session_doc_index = []; % Keep track of the session doc index to exclude later

for i = 1:numel(loaded_docs)
    doc = loaded_docs{i};
    if isa(doc,'ndi.document') && isfield(doc.document_properties,'document_class') && ...
       isfield(doc.document_properties.document_class,'class_name') && ...
       strcmp(doc.document_properties.document_class.class_name, 'session') %
        session_doc_count = session_doc_count + 1;
        session_doc_index = i; % Store index
        if session_doc_count > 1
            error('Found more than one document with class_name ''session''. Only one is allowed.');
        end
        % Extract reference
        if isfield(doc.document_properties, 'session') && isfield(doc.document_properties.session,'reference')
            session_ref_name = doc.document_properties.session.reference; %
        else
            error('Found ''session'' document, but it is missing the ''session.reference'' field.');
        end
        % Extract original session ID from base.session_id
        if isfield(doc.document_properties, 'base') && isfield(doc.document_properties.base,'session_id') && ~isempty(doc.document_properties.base.session_id)
            original_session_id = doc.document_properties.base.session_id; %
        else
             error('Found ''session'' document, but its ''base.session_id'' field is missing or empty.');
        end
    end
end

if session_doc_count < 1
    error('Could not find a document with class_name ''session'' in the loaded data.');
end
if isempty(session_ref_name)
     error('The session reference extracted from the ''session'' document is empty.');
end
if isempty(original_session_id)
     error('The session ID extracted from the ''session'' document is empty.');
end
disp(['Found session reference: ''' session_ref_name ''' and original ID: ' original_session_id]);

% --- Create Target Session Directory and Session Object ---
disp(['Creating new NDI session directory at ' target '...']);
if ~isfolder(target)
    mkdir(target);
end

disp(['Creating new ndi.session.dir object with reference ''' session_ref_name ''' and ID ' original_session_id '...']);
try
    % Attempt to create session using assumed third argument for ID
    S = ndi.session.dir(session_ref_name, target, original_session_id); % Assumed constructor
    disp(['Session created with ID: ' S.id()]);
    % Verify the ID was set correctly
    if ~strcmp(S.id(), original_session_id)
         warning('The session ID set by the constructor (%s) does not match the expected original ID (%s). There might be an issue with the assumed constructor.', S.id(), original_session_id);
    end
catch session_create_err
    % Check if the error is due to wrong number of inputs, suggesting the 3-arg constructor isn't supported
    if strcmp(session_create_err.identifier, 'MATLAB:narginchk:tooManyInputs') || contains(session_create_err.message,'Too many input arguments') || strcmp(session_create_err.identifier, 'MATLAB:minrhs')
         error(['Failed to create ndi.session.dir using the assumed 3-argument constructor (reference, path, id). '...
              'This constructor might not be supported. Original error: %s'], session_create_err.message);
    else
        error(['Failed to create ndi.session.dir at ' target '. Error: ' session_create_err.message]);
    end
end

% --- Prepare documents for bulk addition ---
disp('Preparing documents for database addition...');
docs_for_db = {}; % Cell array to hold documents to be added
new_session_id = S.id(); % Get the ID of the session we created

for i = 1:numel(loaded_docs)
    if i == session_doc_index % Skip the session document itself
        continue;
    end

    doc = loaded_docs{i};
    if ~isa(doc, 'ndi.document')
        warning(['Item ' num2str(i) ' in loaded data is not an ndi.document. Skipping addition.']);
        continue;
    end

    try
        % Update session ID on the document directly (assuming handle behavior is okay here or copies are made by database_add)
        doc = doc.set_session_id(new_session_id); %
        docs_for_db{end+1} = doc;
    catch setid_err
        warning(['Could not set session ID for document ' num2str(i) ' (Original ID ' loaded_docs{i}.id() '). Error: ' setid_err.message '. Skipping.']);
    end
end

% --- Add Documents to New Session Database in Bulk ---
if ~isempty(docs_for_db)
    disp(['Adding ' num2str(numel(docs_for_db)) ' documents to the new session database...']);
    try
        S.database_add(docs_for_db); % Add all prepared documents at once
        disp('Bulk document addition complete.');
    catch db_add_err
        error(['Failed to add documents to the database. Error: ' db_add_err.message]);
    end
else
    disp('No documents (other than the session document itself) to add to the database.');
end

disp(['NDI session created successfully at: ' target]);

end % main function