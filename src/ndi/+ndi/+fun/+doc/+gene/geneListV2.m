function docs = geneListV2(session, tsvPath, nGenes, options)
%GENELISTV2 The v2 record of a gene list, for a v2 database.
%
%   DOCS = ndi.fun.doc.gene.geneListV2(SESSION, TSVPATH, NGENES, ...) returns,
%   as ndi.document objects for SESSION (whose database is v2,
%   ndi.session/writesV2), the documents DID-matlab's
%   +did2/+convert/+migrators_j/gene_list.m gives the v1 `geneList` that
%   ndi.fun.doc.gene.makeGeneList writes for the same input:
%
%     a `term`          a standalone value document, `data_body` true;
%     its `opaque_body` owner the term, holding genes.tsv (TSVPATH, ingested)
%                       unchanged under the name `genes.tsv`; format
%                       EDAM:format_3475 "TSV"; one dimension NCIT:C16612
%                       "Gene" of NGENES positions; notes the label (when not
%                       blank); the two namespaces, when given, as conditions:
%                       EMPTY:0000436 "identifier namespace" and EMPTY:0000437
%                       "symbol namespace", each as text;
%     the history       when given, the annotation source and then the genome
%                       assembly, each a minimal `entity` of type NCIT:C47824
%                       "Data Set" named by its text, and a `directed_relation`
%                       prov:wasDerivedFrom from the step before it (the term,
%                       then the annotation) whose method's one parameter keeps
%                       the text: GENEPIO:0000096 "genome annotation source",
%                       NCIT:C164815 "Reference Genome Assembly Version".
%
%   DOCS is {term, body, annotation entity, its relation, assembly entity, its
%   relation}, without the history steps that were not given. Nothing is
%   written to the database here. gene_name_completeness and
%   n_duplicate_gene_names are not written: the migrator drops them, as they
%   are computable from genes.tsv.
%
%   The shape is did-schema did_v2_go_forward_class_audit.md [gene list as a
%   term, file kept] (2026-11-01) with [gene-list facts split], [gene-list
%   history entities], [gene symbol namespace kept], [annotation source is
%   GENEPIO] and [namespace variable terms] (2026-11-07); writing it into a v2
%   database is [writers are given the session] with [v2 line reads and writes
%   both] (2026-11-03).
%
%   Options:
%     'label', 'geneIdNamespace', 'geneSymbolNamespace', 'annotationSource',
%     'genomeAssembly'   as ndi.fun.doc.gene.makeGeneList takes them ('' is
%                        not written)
%     'DeleteOriginal'   default true: TSVPATH is deleted once the database
%                        has copied it, as makeGeneList's v1 document does
%
%   See also ndi.fun.doc.gene.makeGeneList, ndi.setup.V2.attachFile.

arguments
    session (1,1)
    tsvPath {mustBeTextScalar, mustBeNonzeroLengthText}
    nGenes (1,1) double {mustBeInteger, mustBeNonnegative}
    options.label {mustBeTextScalar} = ''
    options.geneIdNamespace {mustBeTextScalar} = ''
    options.geneSymbolNamespace {mustBeTextScalar} = ''
    options.annotationSource {mustBeTextScalar} = ''
    options.genomeAssembly {mustBeTextScalar} = ''
    options.DeleteOriginal (1,1) logical = true
end

sid = char(session.id());
term = did2.build.document('term', struct('data_body', true), 'SessionId', sid);
id = term.base.id;

bodyOpts = {'SessionId', sid, 'Dimensions', ...
    did2.build.dimension(ndi.setup.V2.registeredTerm('NCIT:C16612', 'Gene'), nGenes)};
label = char(options.label);
if ~isempty(strtrim(label))
    bodyOpts = [bodyOpts, {'Notes', label}];
end
% the two namespaces say how to read genes.tsv: conditions on its body
conds = {};
idNs = factText(options.geneIdNamespace);
if ~isempty(idNs)
    conds{end+1} = did2.build.condition( ...
        ndi.setup.V2.registeredTerm('EMPTY:0000436', 'identifier namespace'), 'Text', idNs);
end
symNs = factText(options.geneSymbolNamespace);
if ~isempty(symNs)
    conds{end+1} = did2.build.condition( ...
        ndi.setup.V2.registeredTerm('EMPTY:0000437', 'symbol namespace'), 'Text', symNs);
end
if ~isempty(conds)
    bodyOpts = [bodyOpts, {'Conditions', did2.build.list(conds{:})}];
end
body = did2.build.opaqueBody(id, did2.build.formatTerm('EDAM:format_3475'), bodyOpts{:});
% the file keeps the name the v1 document gives it, as the migrator keeps the
% v1 `files` block
body.files = struct('file_list', {{'genes.tsv'}});
body = ndi.setup.V2.attachFile(body, 'genes.tsv', char(tsvPath), ...
    'DeleteOriginal', options.DeleteOriginal);

% the history: gene list -> annotation -> assembly, each a minimal Data Set
% named by the text
structs = {term, body};
child = id;
steps = { ...
    options.annotationSource, 'GENEPIO:0000096', 'genome annotation source'; ...
    options.genomeAssembly,   'NCIT:C164815',    'Reference Genome Assembly Version'};
for k = 1:size(steps, 1)
    v = factText(steps{k, 1});
    if isempty(v)
        continue;
    end
    ent = did2.build.document('entity', struct( ...
        'type', ndi.setup.V2.registeredTerm('NCIT:C47824', 'Data Set'), 'name', v), ...
        'SessionId', sid);
    param = did2.build.parameter(ndi.setup.V2.registeredTerm(steps{k, 2}, steps{k, 3}), ...
        'Text', v);
    rel = did2.build.directedRelation(child, ent.base.id, ...
        ndi.setup.V2.registeredTerm('prov:wasDerivedFrom', 'wasDerivedFrom'), ...
        'MethodParameters', param, 'SessionId', sid);
    structs = [structs, {ent, rel}]; %#ok<AGROW>
    child = ent.base.id;
end
docs = cellfun(@(x) ndi.document(x), structs, 'UniformOutput', false);
end

function v = factText(v)
% V as char, '' when blank (makeGeneList's default), as the migrator reads it
v = char(v);
if isempty(strtrim(v))
    v = '';
end
end
