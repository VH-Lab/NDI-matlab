function [out, local] = curie(identifiers)
%CURIE Spec identifiers as V_eta global identifiers (CURIE or IRI strings).
%
%   [OUT, LOCAL] = ndi.setup.V2.curie(IDENTIFIERS) turns a spec's
%   `identifiers`, a list of {scheme, value}, into the strings
%   `entity.global_identifier` holds on a schema built on or after 2026-10-08:
%   a CURIE whose prefix is registered in CURIE_lookups_meta.json
%   ('orcid:0000-0001-6282-7124', 'doi:10.7554/eLife...', 'ror:03xez1567',
%   'rrid:SCR_015773'), or the full IRI for a URL. A value given as its
%   resolver's address ('https://orcid.org/...') is reduced to the local id.
%
%   An award number is not a global identifier -- it is unique only within its
%   funder -- so it is returned as LOCAL ('' if none), for the funding entity's
%   local_identifier (V_eta_entity_composition_plan.md sec. 6).
%
%   Errors ndi:setup:V2:unknownScheme for a scheme with no prefix.

out = {};
local = '';
if isempty(identifiers)
    return;
end
if isstruct(identifiers)
    identifiers = num2cell(identifiers);
end
resolvers = {'orcid', 'https://orcid.org/'; 'ror', 'https://ror.org/'; ...
    'doi', 'https://doi.org/'; 'doi', 'http://dx.doi.org/'; ...
    'pubmed', 'https://pubmed.ncbi.nlm.nih.gov/'; ...
    'wikidata', 'https://www.wikidata.org/wiki/'};
for k = 1:numel(identifiers)
    id = identifiers{k};
    scheme = id.scheme;
    if isstruct(scheme)
        scheme = scheme.name;
    end
    scheme = lower(char(scheme));
    value = strtrim(char(id.value));
    switch scheme
        case 'url'
            out{end+1} = value; %#ok<AGROW>
            continue;
        case 'awardnumber'
            local = value;
            continue;
        case {'orcid', 'ror', 'doi', 'rrid', 'wikidata', 'swh', 'ndicloud', 'wormbase', 'ncbitaxon'}
            prefix = scheme;
        case 'pmid'
            prefix = 'pubmed';
        case 'pmcid'
            prefix = 'pmc';
        case 'swhid'
            prefix = 'swh';
        otherwise
            error('ndi:setup:V2:unknownScheme', ...
                'Identifier scheme "%s" has no registered prefix.', scheme);
    end
    for r = 1:size(resolvers, 1)
        if strcmp(resolvers{r, 1}, prefix) && startsWith(value, resolvers{r, 2}, 'IgnoreCase', true)
            value = value(numel(resolvers{r, 2}) + 1:end);
        end
    end
    if startsWith(value, [prefix ':'], 'IgnoreCase', true)
        value = value(numel(prefix) + 2:end);
    end
    out{end+1} = [prefix ':' value]; %#ok<AGROW>
end
end
