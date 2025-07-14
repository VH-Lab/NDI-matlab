function unique_data = get_unique_bath_components(ndi_session_obj)
%GET_UNIQUE_BATH_COMPONENTS - Extract unique ontologyName and name entries from stimulus_bath documents.
%
%   UNIQUE_DATA = GET_UNIQUE_BATH_COMPONENTS(NDI_SESSION_OBJ)
%
%   This function searches for all documents of type 'stimulus_bath' within
%   the provided NDI session or dataset object, extracts the 'ontologyName' and 'name'
%   entries from their 'mixture_table' fields, and returns a table containing
%   the unique combinations of these entries.
%
%   Inputs:
%       NDI_SESSION_OBJ: An ndi.session or ndi.dataset object representing the NDI session
%                        or dataset to search.
%
%   Outputs:
%       UNIQUE_DATA: A Matlab table containing the unique combinations of
%                    'ontologyName' and 'name' entries found in the
%                    'mixture_table' fields of all 'stimulus_bath' documents.
%
% Example:
%   % if S is an ndi.session or ndi.dataset object
%   unique_data = ndi.example.fun.get_unique_bath_components(S);
%


% Search for documents of type stimulus_bath
stimulus_bath_docs = ndi_session_obj.database_search(ndi.query('','isa','stimulus_bath'));

if isempty(stimulus_bath_docs)
    disp('No documents of type stimulus_bath found')
    unique_data = table(); % Return empty table if no documents found
else
    % Initialize an empty table to store all ontologyName and name pairs
    all_data = table();

    % Loop through the documents and collect ontologyName and name fields
    for i=1:numel(stimulus_bath_docs)
        % Access the mixture_table from the document
        mixtable_str = stimulus_bath_docs{i}.document_properties.stimulus_bath.mixture_table;

        % Convert the string representation of the table to a Matlab table object
        mixtable = ndi.database.fun.readtablechar(mixtable_str, 'txt');  % Use 'txt' as the file type

        % Keep only the 'ontologyName' and 'name' columns
        mixtable = mixtable(:, {'ontologyName', 'name'});

        % Append the filtered mixtable to the all_data table
        all_data = [all_data; mixtable];
    end

    % Find unique rows in the combined table
    unique_data = unique(all_data, 'rows');

end

