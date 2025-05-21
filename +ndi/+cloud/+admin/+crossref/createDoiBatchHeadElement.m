function headElement = createDoiBatchHeadElement()
% createDoiBatchHeadElement - Create a structure representing the head element 
% of the doi_batch element of the metadata record submission xml

    %Reference: 
    % https://data.crossref.org/reports/help/schema_doc/5.3.1/index.html

    
    timeStamp = string(datetime("now", ...
        "Format", 'yyyy-MM-dd''T''HH:mm:ssXXX', ...
        'TimeZone', 'local'));

    % Publisher generated ID that uniquely identifies the DOI submission batch.
    doiBatchId = sprintf("dataset_batch-%s", timeStamp);
    
    % An integer representation of date and time that serves as a version 
    % number for the record that is being deposited, used to uniquely identify 
    % batch files and DOI values when a DOI has been updated one or more times.
    timestamp = datetime("now", "Format", "yyyyMMddHHmmss");
    
    % depositor name: name of organization
    % depositor e-mail: email address to which batch success and/or error
    % messages are sent.

    % Create depositor object
    depositor = crossref.model.Depositor(...
        'DepositorName', ndi.cloud.admin.crossref.Constants.DatabaseOrganization, ...
        'EmailAddress', 'steve@walthamdatascience.com' ...
    );
    
    % Create head object
    headElement = crossref.model.Head(...
        'DoiBatchId', doiBatchId, ...
        'Timestamp', timestamp, ...
        'Depositor', depositor, ...
        'Registrant', ndi.cloud.admin.crossref.Constants.DatabaseOrganization ...
    );
end
