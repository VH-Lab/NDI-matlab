function notes = readNotes(meta, geneID)
% READNOTES - what a full read found that a probe could not
%
%   NOTES = ndi.fun.doc.gene.READNOTES(META, GENEID)
%
%   Turns the meta of an ndr.format.stereoseq reader into a cellstr of
%   things a caller should be told after the fact.
%
%   THESE ARE REPORTED, NOT RAISED. None of them makes the pyramid wrong
%   and all of them change what it means: counts that hit the ceiling read
%   low, an extent that came from attributes rather than from the records
%   is a claim rather than a measurement, and a gene table trimmed by
%   maxGenes leaves a pyramid missing genes with nothing in it saying so.
%
%   They cannot be part of a pre-flight confirmation, which is the reason
%   this exists separately from the checks that can: every one of them
%   needs every record to have been read.
%
%   Inputs:
%   META   - the meta struct from ndr.format.stereoseq.readGEF
%   GENEID - the gene accessions that came back
%
%   Outputs:
%   NOTES - cellstr column, empty when there is nothing to say
%
%   See also: ndi.fun.doc.gene.fromGEF, ndr.format.stereoseq.readGEF

arguments
    meta (1,1) struct
    geneID cell
end

notes = {};

nClamped = localField(meta, 'nCountsClamped', 0);
if nClamped > 0
    notes{end+1} = sprintf(['%s count(s) were clamped at the ceiling. ' ...
        'Those pixels read low.'], localComma(nClamped));
end

src = localField(meta, 'boxSource', '');
if ~isempty(src)
    notes{end+1} = sprintf('Extent taken from %s.', src);
end

% SAW computes its own per-gene MID totals in /stat/gene. Agreeing with the
% instrument vendor's own count is a stronger check than the MATLAB and
% Python ports agreeing with each other, which only shows they made the
% same choices.
if isfield(meta, 'statTotals') && ~isempty(meta.statTotals)
    note = localField(meta, 'statTotalsNote', '');
    if ~isempty(note)
        notes{end+1} = sprintf('SAW /stat/gene: %s', note);
    end
end

nInFile = localField(meta, 'nGenesInFile', numel(geneID));
if nInFile > numel(geneID)
    notes{end+1} = sprintf(['Only %d of the file''s %d genes were read. ' ...
        'The pyramid is missing the rest and nothing in it says so.'], ...
        numel(geneID), nInFile);
end

if isempty(geneID)
    notes{end+1} = 'The read returned no genes.';
end

notes = notes(:);

end % readNotes

% ------------------------------------------------------------------------

function v = localField(s, name, dflt)
if isstruct(s) && isfield(s, name), v = s.(name); else, v = dflt; end
end

function s = localComma(n)
s = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', '$1,');
end
