function registerDatasetDOI( cloudDatasetID, options)

    arguments
        cloudDatasetID (1,1) string
        options.OutputFile (1,1) string = missing
    end

    if ismissing(options.OutputFile)
        options.OutputFile = [tempname, '.xml'];
    end

    [dataset, ~] = ndi.cloud.api.datasets.get_dataset(cloudDatasetID);
    crossrefDataset = ndi.cloud.admin.crossref.convertCloudDatasetToCrossrefDataset(dataset);
    doiBatchSubmissionMetadata = ndi.cloud.admin.createDoiBatchSubmission(crossrefDataset);

    % Generate XML
    xmlStr = doiBatchSubmissionMetadata.toXmlString();
    
    % Save the XML to a file if requested
    if ~isempty(options.OutputFile)
        fid = fopen(options.OutputFile, 'w');
        if fid == -1
            error('CROSSREF:jsonToXml:FileError', ...
                  'Could not open file for writing: %s', options.OutputFile);
        end
        fprintf(fid, '%s', xmlStr);
        fclose(fid);
    end
    
    % Todo: Upload to the crossref api. % Todo: use secrets?
    username = getenv('CROSSREF_USERNAME');
    password = getenv('CROSSREF_PASSWORD');
    
    % Todo: api function...

end