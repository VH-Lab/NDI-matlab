function T = v1TemplateIndex()
%V1TEMPLATEINDEX NDI's v1 document templates, as did2.schema.v1Templates indexes them.
%
%   T = ndi.database.internal.v1TemplateIndex() returns the
%   did2.schema.v1Templates index (present, root, count, byClass) of the
%   templates NDI's own v1 writers build documents from:
%   ndi.common.PathConstants.DocumentFolder, and every NDIcalc calculator
%   template folder on the path (ndi.common.PathConstants.CalcDoc).
%
%   ONE ROOT. did2.schema.v1Templates reads one folder and resolves a
%   superclass by its path under that folder ('$NDIDOCUMENTPATH/base.json'
%   -> base.json), else by file name anywhere under it. A calculator
%   template lives in an NDIcalc repository and names NDI's base.json and
%   calculator.json as superclasses, so read from its own folder it would
%   lose them. When calculator template folders exist, they are therefore
%   copied, once per MATLAB session, into one temporary folder together
%   with NDI's templates (NDI's at the top, each calculator folder under
%   ndicalc_<k>/), and that folder is indexed. With no calculator folder,
%   NDI's DocumentFolder is indexed in place.
%
%   did2.schema.v1Templates caches the index of the last root it read, so
%   this costs one read of the templates per MATLAB session.
%
%   See also ndi.database.internal.stampV1Write, did2.schema.v1Templates.

persistent mergedRoot mergedFrom

main = char(ndi.common.PathConstants.DocumentFolder);
calc = {};
try
    c = ndi.common.PathConstants.CalcDoc;
    if ischar(c) || isstring(c)
        c = cellstr(c);
    end
    for k = 1:numel(c)
        if ~isempty(c{k}) && isfolder(c{k})
            calc{end+1} = char(c{k}); %#ok<AGROW>
        end
    end
catch
    calc = {};
end

if isempty(calc)
    T = did2.schema.v1Templates(main);
    return;
end

from = [{main}, calc];
if isempty(mergedRoot) || ~isfolder(mergedRoot) || ~isequal(mergedFrom, from)
    root = tempname;
    mkdir(root);
    copyfile(fullfile(main, '*'), root);
    for k = 1:numel(calc)
        dest = fullfile(root, sprintf('ndicalc_%d', k));
        mkdir(dest);
        copyfile(fullfile(calc{k}, '*'), dest);
    end
    mergedRoot = root;
    mergedFrom = from;
end
T = did2.schema.v1Templates(mergedRoot);
end
