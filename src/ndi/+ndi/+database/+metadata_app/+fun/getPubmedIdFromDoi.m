function [pmId, pmcId] = getPubmedIdFromDoi(doi)

    arguments
        doi (1,1) string {mustBeValidDoi(doi)}
    end

    doi = cleanDoi(doi); % Local function

    BASE_URL = "https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0";

    requestParams = struct(...
        'idtype', 'doi', ...
        'ids', doi, ...
        'email', 'info@walthamdatascience.com', ...
        'tool', 'ndi-cloud', ...
        'format', 'json');

    queryParam = matlab.net.QueryParameter(requestParams);
    requestURI = matlab.net.URI(BASE_URL, queryParam);

    jsonResponse = webread( requestURI );
    if isfield(jsonResponse.records, 'status')
        if strcmp(jsonResponse.records.status, 'error')
            error(jsonResponse.records.errmsg)
        else
            error('Something unexpected happened')
        end
    elseif isfield(jsonResponse.records, 'pmid')
        pmId = jsonResponse.records.pmid;
        pmcId = jsonResponse.records.pmcid;
    else
        error('Something unexpected happened')
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
