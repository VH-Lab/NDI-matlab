function L = strainLeftovers(f, lookup)
%STRAINLEFTOVERS The openMINDS Strain fields beyond name, species, genetic
%   strain type, phenotype, laboratory code, synonym, description,
%   ontologyIdentifier and backgroundStrain: where each one goes on did-schema
%   #88.
%
%   L = ndi.migrate.internal.strainLeftovers(F, LOOKUP)
%
%   F is a Strain's `openminds.fields` struct. LOOKUP is a function handle:
%   LOOKUP(ID) returns the openMINDS document body whose base.id is ID (an
%   `ndi://` child the writer flattened into its own document,
%   openMINDSobj2struct), or [] when it is not in the batch.
%
%   THE DECISION. Decided by Jess Haley, 2026-10-27 [openMINDS strain
%   leftovers] and 2026-10-30 [openMINDS strain leftovers settled]
%   (did-schema V_eta_go_forward_class_audit.md; docs/V2_PLAN.md G49,
%   did-schema #158):
%     digitalIdentifier, alternateIdentifier
%         -> the strain entity's `global_identifier` (a list; several
%            identifiers all go there)
%     stockNumber
%         -> an RRID in `global_identifier` when the vendor (the linked
%            openMINDS Organization's short name) is JAX (`RRID:IMSR_JAX:<n>`),
%            MMRRC (`RRID:MMRRC_<id>`) or Bloomington (`RRID:BDSC_<n>`);
%            otherwise (CGC included) a text assertion, variable NCIT:C99286
%            "Catalog Number", the number as text
%     breedingType
%         -> a term assertion, variable NCIT:C42877 "breeding"; its value the
%            openMINDS breeding-type term, or NCIT:C28422 "Inbred Strain" /
%            EFO:0004430 "outbred" when the term names one of those and
%            gives no identifier
%     diseaseModel
%         -> a term assertion each, variable BAO:0010279 "disease model"
%     lookupLabel
%         -> not stored: openMINDS's generated display label
%
%   L has fields
%     identifiers     cellstr, in source order, unique (digitalIdentifier,
%                     alternateIdentifier, then the stock RRID)
%     catalog_number  char, '' when none or when it became an RRID
%     breeding        {node, name}, both '' when none
%     diseases        cell of {node, name}
%     unplaced        cellstr: what cannot be placed (the caller carries the
%                     Strain as v1 under carry-092)
%     consumable      cellstr: ids of the child documents read here whose
%                     every non-empty field is written (an identifier
%                     document, a StockNumber whose vendor the RRID encodes or
%                     that has none, a breeding-type or disease term), so
%                     the caller may consume them
%     key             char: the leftovers as one comparable string (dedup)
%
%   Pure: no database, no schema.
%
%   See also ndi.migrate.internal.strainAssembly,
%   ndi.migrate.internal.subjectStrainAssembly.

L = struct('identifiers', {{}}, 'catalog_number', '', ...
    'breeding', emptyTerm(), 'diseases', {{}}, 'unplaced', {{}}, ...
    'consumable', {{}}, 'key', '');
if ~isstruct(f) || ~isscalar(f)
    return;
end

% ---- digitalIdentifier, alternateIdentifier -> global_identifier ---------
for nm = {{'digitalIdentifier', 'digital_identifier'}, ...
          {'alternateIdentifier', 'alternate_identifier'}}
    v = getAny(f, nm{1});
    vals = asCellstr(v);
    if ~isEmptyValue(v) && isempty(vals)
        L.unplaced{end+1} = sprintf('%s (not text)', nm{1}{1});
    end
    for k = 1:numel(vals)
        e = strtrim(vals{k});
        if isempty(e); continue; end
        if startsWith(e, 'ndi://')
            id = e(7:end);
            doc = lookup(id);
            if isempty(doc)
                L.unplaced{end+1} = sprintf('%s (reference %s not in the batch)', nm{1}{1}, id);
                continue;
            end
            ff = openmindsFields(doc);
            idText = charField(ff, {'identifier'});
            if isempty(idText)
                L.unplaced{end+1} = sprintf('%s (document %s states no identifier)', nm{1}{1}, id);
                continue;
            end
            L = addIdentifier(L, idText);
            if onlyFields(ff, {'identifier'})
                L.consumable{end+1} = id;
            end
        else
            L = addIdentifier(L, e);
        end
    end
end

% ---- stockNumber -> RRID, or a Catalog Number text assertion -------------
v = getAny(f, {'stockNumber', 'stock_number'});
if ~isEmptyValue(v)
    vals = asCellstr(v);
    if isempty(vals)
        L.unplaced{end+1} = 'stockNumber (not text)';
    elseif numel(vals) > 1
        L.unplaced{end+1} = sprintf('stockNumber (%d values)', numel(vals));
    elseif ~isempty(vals)
        e = strtrim(vals{1});
        number = e;
        vendor = '';
        stockId = '';
        vendorRead = true;
        if startsWith(e, 'ndi://')
            stockId = e(7:end);
            doc = lookup(stockId);
            number = '';
            if ~isempty(doc)
                ff = openmindsFields(doc);
                number = charField(ff, {'identifier'});
                vendorRefs = ndiRefs(getAny(ff, {'vendor'}));
                if numel(vendorRefs) == 1
                    org = lookup(vendorRefs{1});
                    if isempty(org)
                        vendorRead = false;
                    else
                        vendor = charField(openmindsFields(org), {'shortName', 'short_name'});
                    end
                elseif numel(vendorRefs) > 1
                    vendorRead = false;
                end
            end
            if isempty(number)
                L.unplaced{end+1} = sprintf('stockNumber (reference %s not in the batch or states no identifier)', stockId);
            end
        end
        if ~isempty(number)
            rrid = stockRrid(vendor, number);
            if ~isempty(rrid)
                L = addIdentifier(L, rrid);
                % the RRID's prefix says the vendor: the StockNumber is placed
                if ~isempty(stockId) && onlyFields(openmindsFields(lookup(stockId)), {'identifier', 'vendor'})
                    L.consumable{end+1} = stockId;
                end
            else
                L.catalog_number = number;
                % a vendor the catalog number does not say keeps its
                % StockNumber document (carried as v1, with its vendor link)
                if ~isempty(stockId) && vendorRead && isempty(vendor) ...
                        && onlyFields(openmindsFields(lookup(stockId)), {'identifier'})
                    L.consumable{end+1} = stockId;
                end
            end
        end
    end
end

% ---- breedingType -> a term assertion -------------------------------------
v = getAny(f, {'breedingType', 'breeding_type'});
if ~isEmptyValue(v)
    [terms, why, frags] = readTerms(v, lookup, 'breedingType');
    L.unplaced = [L.unplaced, why];
    if numel(terms) > 1
        L.unplaced{end+1} = sprintf('breedingType (%d values)', numel(terms));
    elseif numel(terms) == 1
        L.breeding = breedingTerm(terms{1});
        L.consumable = [L.consumable, frags];
    end
end

% ---- diseaseModel -> a term assertion each --------------------------------
v = getAny(f, {'diseaseModel', 'disease_model'});
if ~isEmptyValue(v)
    [terms, why, frags] = readTerms(v, lookup, 'diseaseModel');
    L.unplaced = [L.unplaced, why];
    L.diseases = terms;
    L.consumable = [L.consumable, frags];
end

% lookupLabel: openMINDS's generated display label, not stored (regenerated)

parts = [L.identifiers, {L.catalog_number, L.breeding.node, L.breeding.name}];
for k = 1:numel(L.diseases)
    parts = [parts, {L.diseases{k}.node, L.diseases{k}.name}]; %#ok<AGROW>
end
L.key = strjoin(parts, char(31));
end

% ===================== the stock number ===================================

function r = stockRrid(vendor, number)
%STOCKRRID The RRID of a stock number when its vendor has one
%   ([openMINDS strain leftovers settled]: each form resolved at
%   scicrunch.org/resolver, 2026-10-30), else ''. A number already written as
%   an RRID is kept as given.
r = '';
number = strtrim(number);
if startsWith(number, 'RRID:', 'IgnoreCase', true)
    r = ['RRID:' number(6:end)];
    return;
end
switch lower(strtrim(vendor))
    case {'jax', 'the jackson laboratory', 'jackson laboratory'}
        r = ['RRID:IMSR_JAX:' number];
    case {'mmrrc'}
        r = ['RRID:MMRRC_' number];
    case {'bdsc', 'bloomington', 'bloomington drosophila stock center'}
        r = ['RRID:BDSC_' number];
end
end

% ===================== terms ===============================================

function t = breedingTerm(t)
%BREEDINGTERM The openMINDS breeding-type term; when it names inbred or
%   outbred and gives no identifier, the registered term
%   ([openMINDS strain leftovers settled]).
if ~isempty(t.node)
    return;
end
switch lower(strtrim(t.name))
    case {'inbred', 'inbred strain'}
        t = struct('node', 'NCIT:C28422', 'name', 'Inbred Strain');
    case {'outbred', 'outbred strain'}
        t = struct('node', 'EFO:0004430', 'name', 'outbred');
end
end

function [terms, why, frags] = readTerms(v, lookup, fieldName)
%READTERMS Each value as a term: an inline name, or an `ndi://` controlled-term
%   document's name and ONE identifier. Any other field (a definition or
%   synonym included) keeps the document, carried as v1: [openMINDS strain
%   leftovers] drops a fragment's definition and synonyms only for Species
%   and GeneticStrainType (strainAssembly fragmentFullyPlaced). FRAGS lists
%   only the fully placed ones.
terms = {};
why = {};
frags = {};
vals = asCellstr(v);
if isempty(vals)
    why{end+1} = sprintf('%s (not text)', fieldName);
end
for k = 1:numel(vals)
    e = strtrim(vals{k});
    if isempty(e); continue; end
    if ~startsWith(e, 'ndi://')
        terms{end+1} = struct('node', '', 'name', e); %#ok<AGROW>
        continue;
    end
    id = e(7:end);
    doc = lookup(id);
    if isempty(doc)
        why{end+1} = sprintf('%s (reference %s not in the batch)', fieldName, id); %#ok<AGROW>
        continue;
    end
    ff = openmindsFields(doc);
    a = charField(ff, {'preferredOntologyIdentifier', 'preferred_ontology_identifier'});
    b = charField(ff, {'ontologyIdentifier', 'ontology_identifier'});
    nm = charField(ff, {'name'});
    if isempty(nm) && isempty(a) && isempty(b)
        why{end+1} = sprintf('%s (document %s states nothing this pass reads)', fieldName, id); %#ok<AGROW>
        continue;
    end
    node = a;
    if isempty(node); node = b; end
    terms{end+1} = struct('node', node, 'name', nm); %#ok<AGROW>
    if onlyFields(ff, {'name', 'preferredOntologyIdentifier', ...
            'preferred_ontology_identifier', 'ontologyIdentifier', ...
            'ontology_identifier'}) ...
            && (isempty(a) || isempty(b) || strcmp(a, b))
        frags{end+1} = id; %#ok<AGROW>
    end
end
end

% ===================== helpers ============================================

function L = addIdentifier(L, raw)
g = ndi.migrate.internal.etaShape.curie(raw);
if ~isempty(g) && ~any(strcmp(L.identifiers, g))
    L.identifiers{end+1} = g;
end
end

function tf = onlyFields(ff, allowed)
%ONLYFIELDS True when every non-empty field of FF is in ALLOWED.
tf = isstruct(ff);
if ~tf; return; end
fn = fieldnames(ff);
for k = 1:numel(fn)
    if ~isEmptyValue(ff.(fn{k})) && ~any(strcmp(fn{k}, allowed))
        tf = false;
        return;
    end
end
end

function t = emptyTerm()
t = struct('node', '', 'name', '');
end

function f = openmindsFields(s)
% the `openminds` block, or the `openminds_subject` one (the subclass
% template declares both; subjectStrainAssembly reads them in this order)
f = struct();
if ~isstruct(s); return; end
b = [];
if isfield(s, 'openminds') && isstruct(s.openminds)
    b = s.openminds;
elseif isfield(s, 'openminds_subject') && isstruct(s.openminds_subject)
    b = s.openminds_subject;
end
if isstruct(b) && isfield(b, 'fields') && isstruct(b.fields) && isscalar(b.fields)
    f = b.fields;
end
end

function c = asCellstr(v)
%ASCELLSTR A fields value as a cell of char ({} for anything else).
c = {};
if isempty(v); return; end
if ischar(v); c = {v}; return; end
if isstring(v); c = cellstr(v); return; end
if iscell(v)
    for k = 1:numel(v)
        e = v{k};
        if isstring(e); e = char(e); end
        if ischar(e); c{end+1} = e; end %#ok<AGROW>
    end
end
end

function ids = ndiRefs(v)
ids = {};
c = asCellstr(v);
for k = 1:numel(c)
    if startsWith(c{k}, 'ndi://') && numel(c{k}) > 6
        ids{end+1} = c{k}(7:end); %#ok<AGROW>
    end
end
end

function v = getAny(s, names)
v = [];
if ~isstruct(s); return; end
for k = 1:numel(names)
    if isfield(s, names{k}) && ~isempty(s.(names{k}))
        v = s.(names{k});
        return;
    end
end
end

function c = charField(s, names)
c = '';
v = asCellstr(getAny(s, names));
if ~isempty(v); c = strtrim(v{1}); end
end

function tf = isEmptyValue(v)
tf = isempty(v) || ((ischar(v) || (isstring(v) && isscalar(v))) && strlength(strtrim(string(v))) == 0);
end
