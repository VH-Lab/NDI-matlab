function [doc, tsvPath] = makeGeneList(session, geneID, geneName, options)
% MAKEGENELIST - create a geneList document from an ordered gene dictionary
%
%   [DOC, TSVPATH] = ndi.fun.doc.gene.MAKEGENELIST(SESSION, GENEID, GENENAME)
%   [...] = ndi.fun.doc.gene.MAKEGENELIST(..., 'genomeAssembly', A, ...)
%
%   Writes genes.tsv and creates the geneList document that other gene
%   expression documents index against. A geneList holds no counts: its
%   only job is to give a stable meaning to the integer gene_index stored
%   elsewhere. Datasets built on the same annotation should share one.
%
%   Inputs:
%   GENEID   - cellstr of stable accessions, in gene_index order
%   GENENAME - cellstr of symbols, same length; entries may be empty
%
%   Optional Name-Value Arguments:
%   genomeAssembly ('')     - the reference assembly (e.g. 'monDom5'). This
%                             describes the ANNOTATION; the subject's
%                             species belongs in an animalsubject or
%                             openminds_subject document.
%   annotationSource ('')   - identifier of the GTF/GFF, including any
%                             modification. Counts are not reproducible
%                             without it.
%   geneIdNamespace ('')    - e.g. 'Ensembl'
%   geneSymbolNamespace('') - e.g. 'HGNC'
%   label ('')              - human-readable label
%
%   Outputs:
%   DOC     - the geneList ndi.document, already added to the database
%   TSVPATH - where genes.tsv was written before ingestion
%
%   n_genes, gene_name_completeness and n_duplicate_gene_names are computed
%   here rather than supplied. The last matters: symbols are NOT unique in
%   real annotations -- the opossum SAW gene list repeats 5,531 of them,
%   PAX8 across 89 rows -- so a consumer that keys on symbol silently
%   discards most of such a gene. Recording the count lets it know not to.
%
%   Example:
%       [d,~] = ndi.fun.doc.gene.makeGeneList(S, ids, names, ...
%                   'genomeAssembly','monDom5','geneIdNamespace','Ensembl');
%
%   See also: ndi.fun.doc.gene.makePyramid
%
arguments
    session (1,1)
    geneID cell
    geneName cell
    options.genomeAssembly (1,:) char = ''
    options.annotationSource (1,:) char = ''
    options.geneIdNamespace (1,:) char = ''
    options.geneSymbolNamespace (1,:) char = ''
    options.label (1,:) char = ''
end

n = numel(geneID);
if numel(geneName) ~= n
    error('NDI:gene:makeGeneList:lengthMismatch', ...
        'GENEID and GENENAME must be the same length (%d, %d).', n, numel(geneName));
end

named = ~cellfun(@isempty, geneName);
completeness = 0;
if n > 0
    completeness = sum(named) / n;
end

% Count symbols carried by more than one row.
nDup = 0;
if any(named)
    [uNames, ~, ic] = unique(geneName(named));
    counts = accumarray(ic(:), 1);
    nDup = sum(counts > 1);
    clear uNames;
end

tsvPath = [tempname '.tsv'];
fid = fopen(tsvPath, 'w');
if fid < 0
    error('NDI:gene:makeGeneList:cannotWrite', ...
        'Could not open ''%s'' for writing.', tsvPath);
end
cl = onCleanup(@() fclose(fid));
fprintf(fid, 'gene_index\tgene_id\tgene_name\n');
for i = 1:n
    % gene_index is written explicitly and is ZERO-BASED, matching the
    % tile files and NDI-python. A reader should assert it rather than
    % trust that row order survived transport.
    fprintf(fid, '%d\t%s\t%s\n', i-1, geneID{i}, geneName{i});
end
clear cl;

s = struct('label', options.label, ...
    'n_genes', n, ...
    'genome_assembly', options.genomeAssembly, ...
    'gene_id_namespace', options.geneIdNamespace, ...
    'gene_symbol_namespace', options.geneSymbolNamespace, ...
    'annotation_source', options.annotationSource, ...
    'gene_name_completeness', completeness, ...
    'n_duplicate_gene_names', nDup);

doc = ndi.document('geneList', 'geneList', s) + session.newdocument();
doc = storeDoc(session, doc, {'genes.tsv'}, {tsvPath});

end % makeGeneList
