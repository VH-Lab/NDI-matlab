function doi = createNewDOI()
    % Todo: Create a random string based on todays date?
    % Todo: include the ndic?

    today = datetime("now");
    counter = 1;
    doiSuffix = sprintf('ndic.%d.%03d', year(today), counter);

    ndiPrefix = ndi.cloud.admin.crossref.Constants.DOIPrefix;
    doi = sprintf('%s/%s', ndiPrefix, doiSuffix);
end
