function registerDatasetDOI(cloudDatasetID, options)
% registerDatasetDOI - Register a Dataset DOI via crossref
%
% Syntax:
%   registerDatasetDOI(cloudDatasetID, options) submit dataset metadata to
%   crossref for DOI registration
%
% Input Arguments:
%   cloudDatasetID (string) - The ID of the dataset in the cloud.
%   options (name-value pairs) - Optional name-value pairs
%       - OutputFile (string) - The file path to save the XML output.
%       - ShowXML (logical) - Flag to display the XML string in the console (default: true).
%       - UseTestSystem (logical) - Flag to use the test system for submission (default: false).
%
% NB: Requires crossref credentials being set as environment variables:
%   CROSSREF_USERNAME, CROSSREF_PASSWORD

    arguments
        cloudDatasetID (1,1) string = missing
        options.OutputFile (1,1) string = missing
        options.ShowXML (1,1) logical = true
        options.UseTestSystem (1,1) logical = false
    end

    if ismissing(options.OutputFile) % Create a temporary file
        options.OutputFile = [tempname, '.xml'];
        cleanupObj = onCleanup(@() deleteIfExists(options.OutputFile));
    end

    if ~ismissing(cloudDatasetID)
        [dataset, ~] = ndi.cloud.api.datasets.get_dataset(cloudDatasetID);
    else
        dataset = [];
    end
    crossrefDataset = ndi.cloud.admin.crossref.convertCloudDatasetToCrossrefDataset(dataset);
    doiBatchSubmissionMetadata = ndi.cloud.admin.crossref.createDoiBatchSubmission(crossrefDataset);

    % Generate XML (saves to provided file path)
    xmlString = doiBatchSubmissionMetadata.toXmlString(options.OutputFile);
    if options.ShowXML
        disp(xmlString)
    end
    
    % Validate metadata
    crossref.validateMetadata(options.OutputFile)
    
    % Upload to the crossref API. % Todo: use secrets if available?
    username = getenv('CROSSREF_USERNAME');
    password = getenv('CROSSREF_PASSWORD');
    
    % Post the submission metadata xml file to Crossref
    crossref.registerDOI(options.OutputFile, ...
        "UserName", username, ...
        "Password", password, ...
        "UseTestSystem", options.UseTestSystem)

    [~, filename] = fileparts(options.OutputFile);
    fprintf('Deposited file with name "%s.xml". You can use this filename to check the submission.\n', filename)
end

function deleteIfExists(fileName)
    if isfile(fileName)
        delete(fileName)
    end
end
