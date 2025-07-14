function licenseObj = convertLicense(cloudDataset)
    
    if ~isfield(cloudDataset, 'license') || isempty(cloudDataset.license)
        licenseObj = crossref.model.AiProgram.empty;
    else
        licenseName = cloudDataset.license;

        try
            licenseDetails = openminds.core.License.fromName(licenseName);
        catch ME
            % brute force
            if strcmp(licenseName, 'ccByNcSa4_0')
                licenseDetails = openminds.core.License.fromName("CC-BY-NC-SA-4.0");
            elseif strcmp(licenseName, 'Creative Commons Attribution 4.0 International')
                licenseDetails = openminds.core.License.fromName("CC-BY-4.0");
            else
                rethrow(ME)
            end
        end

        licenseUrl = licenseDetails.webpage;
        
        licenseObj = crossref.model.AiProgram(...
            "LicenseRef", crossref.model.AiLicenseRef(...
                "Value", licenseUrl(1)));
    end
end
