function S = resolveRelatedPublication(doi)
%resolveRelatedPublication - Resolve publication information based on DOI.
%
%   S = resolveRelatedPublication(doi) retrieves publication information
%   such as title, PubMed ID, and PubMed Central ID using the provided DOI.
%
%   Input:
%   - doi (1x1 string): Digital Object Identifier for the publication.
%
%   Output:
%   - S (struct): Structure containing publication information.
%     - S.doi: Original cleaned DOI.
%     - S.title: Title of the publication.
%     - S.pmid: PubMed ID of the publication.
%     - S.pmcid: PubMed Central ID of the publication.
%
%   Example:
%   doi = '10.1523/ENEURO.0073-21.2022';
%   publicationInfo = ndi.database.metadata_app.fun.resolveRelatedPublication(doi);

    arguments
        doi (1,1) string %{mustBeValidDoi(doi)}
    end

    %doi = cleanDoi(doi); % Local function

    %S.doi = doi;

    [S.title, S.doi] = ndi.database.metadata_app.fun.getPublicationTitleFromDoi(doi);
    [S.pmid, S.pmcid] = ndi.database.metadata_app.fun.getPubmedIdFromDoi(doi);
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