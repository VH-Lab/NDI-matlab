function doc = attachFile(doc, name, location, options)
%ATTACHFILE Say where the bytes of one of a V2 document's files are.
%
%   DOC = ndi.setup.V2.attachFile(DOC, NAME, LOCATION) records that the file
%   NAME of DOC (a document struct built by did2.build: a sampled_body's
%   'body_data_0', an opaque_body's member) is the file LOCATION on this
%   computer. did2.build declares a document's files by name only
%   (`files.file_list`); NDI needs to know where each one is before it can
%   write the document (ndi.setup.V2.createSession, createDataset,
%   writeDocuments) or read it back (ndi.statement/value, ndi.v2.readBody).
%
%   By default the file is INGESTED: the write copies it into the session's
%   or dataset's .ndi/files and reads it from there afterwards; LOCATION is
%   left where it is. 'Ingest', false records it by location instead (a raw
%   recording that stays where the lab keeps it).
%
%   Options:
%     'Ingest'          default true: copy the file into the database's store
%     'DeleteOriginal'  default false: delete LOCATION once it is copied
%
%   NAME must be one of the names the document declares
%   (ndi:setup:V2:undeclaredFile otherwise), and LOCATION must exist
%   (ndi:setup:V2:noFile). Attaching a NAME again replaces its location.
%
%   Example:
%     body = did2.build.sampledBody(obs.base.id, keys, 'ByteOrder', 'little', ...
%         'SessionId', sid);
%     fid = fopen(f, 'w', 'ieee-le'); fwrite(fid, x, 'double'); fclose(fid);
%     body = ndi.setup.V2.attachFile(body, 'body_data_0', f);
%
%   See also did2.build.sampledBody, did2.build.opaqueBody,
%   ndi.setup.V2.writeDocuments.

arguments
    doc (1,1) struct
    name {mustBeTextScalar}
    location {mustBeTextScalar}
    options.Ingest (1,1) logical = true
    options.DeleteOriginal (1,1) logical = false
end

name = char(name);
location = char(location);
declared = {};
if isfield(doc, 'files') && isfield(doc.files, 'file_list')
    declared = cellstr(doc.files.file_list);
end
if ~any(strcmp(declared, name))
    error('ndi:setup:V2:undeclaredFile', ['Document %s declares no file "%s" ' ...
        '(it declares: %s).'], char(doc.base.id), name, strjoin(declared, ', '));
end
if ~isfile(location)
    error('ndi:setup:V2:noFile', 'There is no file %s to attach as "%s".', location, name);
end
entry = struct('name', name, 'locations', struct( ...
    'delete_original', double(options.DeleteOriginal), 'uid', ndi.ido.unique_id(), ...
    'location', location, 'parameters', '', 'location_type', 'file', ...
    'ingest', double(options.Ingest)));
if isfield(doc.files, 'file_info') && ~isempty(doc.files.file_info)
    fi = doc.files.file_info;
    at = find(strcmp({fi.name}, name), 1);
    if isempty(at)
        fi(end+1) = entry;
    else
        fi(at) = entry;
    end
else
    fi = entry;
end
doc.files.file_info = fi;
end
