function [tf, location] = externalFileLocation(document_properties, filename)
%EXTERNALFILELOCATION Where a document's NOT-ingested file lives, if it says.
%
%   [TF, LOCATION] = ndi.database.fun.externalFileLocation(PROPS, FILENAME)
%   reads PROPS.files.file_info -- the per-file record ndi.document/add_file
%   writes -- for the entry named FILENAME, and returns the first of its
%   `locations` that is a local file (`location_type` 'file' or empty) NOT
%   taken into the database (`ingest` false) and that exists on this
%   computer. TF is false (LOCATION '') when there is no such location.
%
%   This is how a document points at bytes it does not hold: a V2
%   `opaque_body` written at import names its recording this way, and the
%   bytes stay where they are until ingestion (Haley import decision #34).
%   A location that is recorded but missing on this computer gives TF false,
%   never an error: a caller asks this speculatively.
%
%   See also ndi.document/add_file,
%            ndi.database.implementations.database.did2sqlite.

tf = false;
location = '';
if ~isfield(document_properties, 'files') || ~isstruct(document_properties.files) ...
        || ~isfield(document_properties.files, 'file_info')
    return;
end
info = asCell(document_properties.files.file_info);
for i = 1:numel(info)
    fi = info{i};
    if ~isstruct(fi) || ~isfield(fi, 'name') || ~strcmp(char(fi.name), filename) ...
            || ~isfield(fi, 'locations')
        continue;
    end
    locs = asCell(fi.locations);
    for j = 1:numel(locs)
        l = locs{j};
        if ~isstruct(l) || ~isfield(l, 'location') || isempty(l.location)
            continue;
        end
        if isfield(l, 'ingest') && ~isempty(l.ingest) && logical(l.ingest(1))
            continue;   % held (or to be held) by the database, not read in place
        end
        if isfield(l, 'location_type') && ~isempty(l.location_type) ...
                && ~strcmpi(char(l.location_type), 'file')
            continue;   % a url / cloud location is not a local path
        end
        p = char(l.location);
        if isfile(p)
            tf = true;
            location = p;
            return;
        end
    end
end
end

function c = asCell(x)
if iscell(x)
    c = x;
elseif isstruct(x)
    c = num2cell(x);
else
    c = {};
end
end
