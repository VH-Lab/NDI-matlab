function registerDatasetDOI( cloudDatasetID, options)
% registerDatasetDOI - Register a Dataset DOI via crossref

    arguments
        cloudDatasetID (1,1) string = missing
        options.OutputFile (1,1) string = missing
        options.ShowXML (1,1) logical = true
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
    crossref.registerDOI(options.OutputFile, "UserName", username, "Password", password)
end

% function saveXmlToFile(xmlStr, fileName)
% fid = fopen(fileName, 'wt');
% if fid == -1
%     error('CROSSREF:jsonToXml:FileError', ...
%         'Could not open file for writing: %s', fileName);
% end
% fprintf(fid, '%s', xmlStr);
% fclose(fid);
% end

function deleteIfExists(fileName)
    if isfile(fileName)
        delete(fileName)
    end
end
