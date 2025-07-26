function epoch_ids = find_epochids_with_temperature(ndi_session_or_dataset_obj, temperature)
% FIND_EPOCHIDS_WITH_TEMPERATURE - Find all epochids where the temperature was held constant at a specified value
%
%   EPOCH_IDS = FIND_EPOCHIDS_WITH_TEMPERATURE(NDI_SESSION_OR_DATASET_OBJ, TEMPERATURE)
%
%   This function searches for all epochs in an NDI session or dataset where the temperature was held
%   constant at a specified value. It returns a cell array of epoch IDs.
%
%   Inputs:
%       NDI_SESSION_OR_DATASET_OBJ: An ndi.session object or an ndi.dataset object representing the session or dataset to search.
%       TEMPERATURE: The temperature value to search for in degrees Celsius.
%
%   Outputs:
%       EPOCH_IDS: A cell array of epoch IDs where the specified temperature was held constant.
%
%   Example:
%       % Find all epochids where the temperature was held constant at 15 degrees Celsius
%       epoch_ids = ndi.example.fun.find_epochids_with_temperature(my_ndi_session, 15);
%


item = ndi.database.fun.ndicloud_ontology_lookup('Name', 'Command temperature constant');

% Search for documents of type stimulus_parameter with property name 'Command temperature constant' and the specified temperature value
temperature_docs = ndi_session_or_dataset_obj.database_search(ndi.query('stimulus_parameter.ontology_name', 'exact_string', ['NDIC:' int2str(item.Identifier) ]) &...
    ndi.query('stimulus_parameter.value', 'exact_number', temperature));

epoch_ids = {}; % Initialize an empty cell array to store epoch IDs

% Loop through the documents and extract epoch_id
if ~isempty(temperature_docs)
    for i = 1:numel(temperature_docs)
        epoch_ids{end+1} = temperature_docs{i}.document_properties.epochid.epochid;
    end
end


