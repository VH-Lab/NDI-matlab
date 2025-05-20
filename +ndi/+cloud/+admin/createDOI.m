function doi = createDOI(doiSuffix)
    % Todo: Create a random string based on todays date?
    ndiPrefix = ndi.cloud.admin.crossref.Constants.DOIPrefix;
    doi = sprintf('%s/ndic%s', ndiPrefix, doiSuffix);
end
