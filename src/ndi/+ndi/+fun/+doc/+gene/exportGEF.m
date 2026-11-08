function info = exportGEF(session, pyrDoc, binSize, filename, options)
% EXPORTGEF - write a Stereo-seq GEF from a stored pyramid level
%
%   INFO = ndi.fun.doc.gene.EXPORTGEF(SESSION, PYRDOC, BINSIZE, FILENAME)
%   INFO = ndi.fun.doc.gene.EXPORTGEF(..., 'resolutionNm', R, ...)
%
%   Produces the /geneExp/bin{N}/{gene,expression} pair SAW writes:
%   expression is a compound array of (x, y, count) grouped by gene, and
%   gene is the index into it, one row per gene with its offset and
%   count. Coordinates are in source chip units.
%
%   Use this when the destination is a STOmics tool, Stereopy, geftools,
%   or a collaborator who does not use NDI. For an animal-filtered
%   pyramid (one of the per-subject pyramids fromGEFbyROI produces) the
%   exported file is just this animal: records outside the drawn polygon
%   were never in the pyramid, so they are not in the exported GEF
%   either.
%
%   THIS IS A WRAPPER around NDI-python's ndi.fun.doc_gene_export.exportGef.
%   NDI-matlab does not have its own GEF writer, and the Python
%   implementation is the authoritative one (every SAW-compat quirk --
%   compound layouts, S64 string padding, attribute placement on both
%   the bin group and the file root -- lives there). Running this from
%   MATLAB shells out to python with the same session and pyramid id,
%   so the output is byte-identical with calling exportGef directly from
%   Python.
%
%   Inputs:
%   SESSION  - an ndi.session or ndi.dataset. Must have a filesystem
%              path (ndi.session.dir or ndi.dataset.dir); a session
%              held only in memory cannot be re-opened by the Python
%              side.
%   PYRDOC   - a spatialGeneExpressionPyramid document
%   BINSIZE  - which level to export (an entry of the pyramid's
%              bin_sizes; 1 for full-resolution records)
%   FILENAME - path to write; the directory must exist, the file is
%              overwritten if it already exists
%
%   Optional Name-Value Arguments:
%   resolutionNm ([]) - DNB pitch in nanometres for the file's
%                       resolution attribute. Empty derives it from
%                       the pyramid's basePixelSizeX (which is in
%                       micrometres; a 0.5 um chip becomes 500 nm).
%   python ('')       - path to the python interpreter. Empty uses
%                       'python3' from PATH; set this when NDI-python
%                       lives in a venv not on the MATLAB session's
%                       PATH (same situation napariViewGEF runs into).
%   verbose (false)   - print the shell command and python output
%
%   Outputs:
%   INFO - a struct with fields filename, binSize, nRecords, nGenes,
%          totalCounts, resolutionNm, exactly mirroring the Python
%          return dict.
%
%   Example:
%       % An animal-filtered pyramid from fromGEFbyROI, exported as a
%       % standalone GEF for a collaborator who uses SAW.
%       pyrDocs = S.database_search(ndi.query('','isa','spatialGeneExpressionPyramid'));
%       info = ndi.fun.doc.gene.exportGEF(S, pyrDocs{1}, 1, ...
%                   '~/share/ferret_gef_1.gef');
%       disp(info);
%
%   See also: ndi.fun.doc.gene.fromGEFbyROI,
%             ndi.fun.doc.gene.fromGEFinteractive,
%             ndi.fun.doc.gene.makePyramid

arguments
    session (1,1)
    pyrDoc (1,1)
    binSize (1,1) {mustBePositive, mustBeInteger}
    filename (1,:) char
    options.resolutionNm double = []
    options.python (1,:) char = ''
    options.verbose (1,1) logical = false
end

sessionPath = '';
if ismethod(session, 'getpath')
    sessionPath = session.getpath();
end
if isempty(sessionPath)
    error('NDI:gene:exportGEF:noSessionPath', ...
        ['This session has no directory on disk, so Python cannot ' ...
         're-open it. exportGEF needs an ndi.session.dir or ' ...
         'ndi.dataset.dir, not a session held only in memory.']);
end

pyrID = pyrDoc.id();

py = strtrim(options.python);
if isempty(py)
    py = 'python3';
end

resolutionLit = 'None';
if ~isempty(options.resolutionNm)
    resolutionLit = sprintf('%d', round(options.resolutionNm));
end

% The Python snippet is one -c string so the error surface is just
% "python exited nonzero", which MATLAB can report straight. Every
% identifier is quoted with localQuote so a path with a space or an
% apostrophe cannot break the string.
pyCode = [ ...
    'import json, sys;', ...
    'from ndi.ndi_dataset import ndi_dataset;', ...
    'from ndi.fun.doc_gene_export import exportGef;', ...
    'ds = ndi_dataset(' localQuote(sessionPath) ');', ...
    'docs = ds.database_search();', ...
    'pyr = next((d for d in docs if d.id == ' localQuote(pyrID) '), None);', ...
    'assert pyr is not None, ' ...
        '"pyramid id " + ' localQuote(pyrID) ' + " is not in this session";', ...
    sprintf('info = exportGef(ds, pyr, %d, %s, resolution_nm=%s);', ...
        binSize, localQuote(filename), resolutionLit), ...
    'json.dump(info, sys.stdout);'];

cmd = [localShellQuote(py) ' -c ' localShellQuote(pyCode)];
if options.verbose
    fprintf('running: %s\n', cmd);
end

[status, out] = system(cmd);
if status ~= 0
    error('NDI:gene:exportGEF:pythonFailed', ...
        ['exportGef from NDI-python failed (exit %d). The Python ' ...
         'interpreter printed:\n%s\n\nIs NDI-python installed in the ' ...
         'environment %s points at? Run its Update window to install ' ...
         'it if not, or pass ''python'' to point at the venv''s ' ...
         'interpreter.'], status, out, py);
end

try
    info = jsondecode(strtrim(out));
catch ME
    error('NDI:gene:exportGEF:badJSON', ...
        ['exportGef ran but did not print a JSON summary; the Python ' ...
         'output was:\n%s\n\nUnderlying parse error: %s'], out, ME.message);
end

if options.verbose
    fprintf(['wrote %s: binSize=%d, nRecords=%d, nGenes=%d, ' ...
             'totalCounts=%d, resolutionNm=%d\n'], ...
        info.filename, info.bin_size, info.n_records, ...
        info.n_genes, info.total_counts, info.resolution_nm);
end

end % exportGEF

% ------------------------------------------------------------------------

function s = localQuote(str)
% LOCALQUOTE - quote a string for inclusion in a Python -c expression
%   Escapes backslash and single-quote so the identifier round-trips
%   verbatim through the shell -c argument.
str = char(str);
str = strrep(str, '\', '\\');
str = strrep(str, '''', '\\''');
s = ['''' str ''''];
end

% ------------------------------------------------------------------------

function s = localShellQuote(str)
% LOCALSHELLQUOTE - quote for the host shell
%   Single-quote the whole argument and escape embedded single-quotes
%   the POSIX way: ' -> '"'"'. On Windows system() runs through cmd.exe
%   where this does not apply; we assume a POSIX shell, matching the
%   convention GEFManager.viewCommand already uses.
str = char(str);
s = ['''' strrep(str, '''', '''"''"''') ''''];
end
