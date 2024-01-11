function [publicationTitle, doi] = getPublicationTitleFromDoi(doi)

    arguments
        doi (1,1) string {mustBeValidDoi(doi)}
    end

    doi = cleanDoi(doi); % Local function

    BASE_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/";

    % Search pubmed for the given DOI
    searchUrl = sprintf("esearch.fcgi?db=pubmed&term=%s", doi);
    
    xmlResponse = webread(BASE_URL + searchUrl);
    searchResult = xml2struct(xmlResponse); % Local function

    if isempty(searchResult.IdList) || (isstring(searchResult.IdList) && searchResult.IdList == "")
        error('NDI:PublicationTitleNotFound', 'Could not find any publication title for the provided doi (%s)', doi)
    end

    % Make sure we got exactly one result it and retrieve it
    assert( numel(searchResult.IdList)==1, 'Expected exactly one match for a valid DOI') 
    
    searchResultId = searchResult.IdList.Id;

    % Download the document associated with the result ID
    downloadUrl = sprintf("esummary.fcgi?db=pubmed&id=%d", searchResultId);
    xmlResponse = webread(BASE_URL + downloadUrl);
    
    % Read the publication title from the document result
    documentResult = xml2struct(xmlResponse);
    isTitleItem = strcmp( [documentResult.DocSum.Item.NameAttribute], "Title" );
    publicationTitle = documentResult.DocSum.Item( isTitleItem ).Text;

    %isDoiItem = strcmp( [documentResult.DocSum.Item.NameAttribute], "DOI" );
    %doi = documentResult.DocSum.Item( isDoiItem ).Text;

    if nargout == 1
        clear doi
    end
end

function S = xml2struct(xmlString)

    % Save to temp xml
    tempPath = [tempname, '.xml'];
    
    fid = fopen(tempPath, 'w');
    fwrite(fid, xmlString);
    fclose(fid);
    
    % Read search result
    S = readstruct(tempPath);
    if isfile(tempPath)
        delete(tempPath)
    end
end

function mustBeValidDoi(doi)
    pattern = '10.[0-9]{4,9}/[-._;()/:A-Za-z0-9]+';
    assert( ~isempty(regexp(doi, pattern, 'once')), ...
        'The doi "%s" does not appear to be valid', doi ) 
end

function doi = cleanDoi(doi)
    if strncmp(doi, 'https://', 8)
        doi = strrep(doi, 'https://', '');
    end

    if strncmp(doi, 'doi.org/', 8)
        doi = strrep(doi, 'doi.org/', '');
    end

end