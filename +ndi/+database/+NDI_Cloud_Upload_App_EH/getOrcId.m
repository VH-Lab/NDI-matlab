function orcid = getOrcid(name)
    
    %name = 'stephen van hooser';
    baseUrl = 'https://pub.orcid.org';
    apiQueryStr = sprintf('/v3.0/expanded-search/?q={!edismax qf="given-and-family-names^50.0 family-name^10.0 given-names^10.0 credit-name^10.0 other-names^5.0 text^1.0" pf="given-and-family-names^50.0" bq="current-institution-affiliation-name:[* TO *]^100.0 past-institution-affiliation-name:[* TO *]^70" mm=1}"%s"&start=0&rows=50', name);
    apiQueryUrl = [baseUrl, apiQueryStr];
    
    S = webread(apiQueryUrl);

    if S.num_found == 0
        orcid = '';
    elseif S.num_found == 1
        orcid = S.expanded_result.orcid_id;
    elseif S.num_found > 1
        error('Multiple entries found')    
    end
end