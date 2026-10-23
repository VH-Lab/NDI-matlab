function [out, local] = curie(identifiers)
%CURIE Spec identifiers as V_eta global identifiers (CURIE or IRI strings).
%
%   [OUT, LOCAL] = ndi.setup.V2.curie(IDENTIFIERS) turns a spec's
%   `identifiers`, a list of {scheme, value}, into the strings
%   `entity.global_identifier` holds:
%   a CURIE whose prefix is registered in CURIE_lookups_meta.json, or the full
%   IRI for a URL. A value given as its resolver's address
%   ('https://orcid.org/...') is reduced to the local id.
%
%   The prefix is written as the registry entry's `spelling`, the way the
%   identifier's issuer cites it ('ORCID:0000-0001-6282-7124', 'ROR:03xez1567',
%   'doi:10.7554/eLife...', 'RRID:SCR_015773', 'PMID:...', 'PMCID:...';
%   did-schema V_eta_prefix_spelling_plan.md, signed 2026-10-19). The scheme
%   names an entry by its key, spelling or any of its synonyms, ignoring case,
%   so 'PMID' and 'pubmed' are one scheme (ndi.v2.curiePrefixes, read from the
%   schema on DID_SCHEMA_PATH). A Cellosaurus or Addgene id is written as the
%   RRID it is cited by ('RRID:CVCL_0030'). On a schema built before the
%   spellings each entry is written as its lowercase key, as that schema
%   expects, and the scheme names `pmid`, `pmcid` and `swhid` still map to
%   their entries.
%
%   An award number is not a global identifier -- it is unique only within its
%   funder -- so it is returned as LOCAL ('' if none), for the funding entity's
%   local_identifier (V_eta_entity_composition_plan.md sec. 6).
%
%   Errors ndi:setup:V2:unknownScheme for a scheme with no prefix.

arguments
    identifiers
end

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
% scheme names a schema built before the spellings carries no synonym for
oldNames = {'pmid', 'pubmed'; 'pmcid', 'pmc'; 'swhid', 'swh'};
ix = ndi.v2.curiePrefixes();
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
    end
    key = schemeKey(scheme, ix, oldNames);
    if isempty(key)
        error('ndi:setup:V2:unknownScheme', ...
            'Identifier scheme "%s" has no registered prefix.', scheme);
    end
    for r = 1:size(resolvers, 1)
        if strcmp(resolvers{r, 1}, key) && startsWith(value, resolvers{r, 2}, 'IgnoreCase', true)
            value = value(numel(resolvers{r, 2}) + 1:end);
        end
    end
    % a value already written as a CURIE of this entry ('RRID:WB-STRAIN:...',
    % 'NCBITaxon:637912') keeps only its local id
    p = regexp(value, '^[A-Za-z][A-Za-z0-9_.\-]*(?=:)', 'match', 'once');
    if ~isempty(p) && strcmp(schemeKey(lower(p), ix, oldNames), key)
        value = value(numel(p) + 2:end);
    end
    out{end+1} = ndi.v2.curieSpelling([key ':' value], ix); %#ok<AGROW>
end
end

function key = schemeKey(scheme, ix, oldNames)
%SCHEMEKEY The registry key a scheme name names, '' if none.
arguments
    scheme (1,:) char
    ix struct
    oldNames cell
end

key = '';
if ix.names.Count == 0
    % no registry readable (DID_SCHEMA_PATH unset): the prefixes this import
    % has always written, as their lowercase keys
    known = {'orcid', 'ror', 'doi', 'rrid', 'wikidata', 'swh', 'ndicloud', ...
        'wormbase', 'ncbitaxon', 'pubmed', 'pmc'};
    k = find(strcmp(oldNames(:, 1), scheme), 1);
    if ~isempty(k)
        scheme = oldNames{k, 2};
    end
    if any(strcmp(known, scheme))
        key = scheme;
    end
    return;
end
if isKey(ix.names, scheme)
    key = ix.names(scheme);
    return;
end
k = find(strcmp(oldNames(:, 1), scheme), 1);
if ~isempty(k) && isKey(ix.names, oldNames{k, 2})
    key = ix.names(oldNames{k, 2});
end
end
