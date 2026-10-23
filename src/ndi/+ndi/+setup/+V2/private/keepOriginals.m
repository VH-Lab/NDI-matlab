function docs = keepOriginals(docs)
%KEEPORIGINALS A copy of DOCS whose ingested files are not deleted once copied.
%
%   Used by ndi.setup.V2.writeDataset ('KeepOriginals') when a dataset ingests
%   its sessions' documents and the same files are ingested again by the
%   session folders written afterwards.

arguments
    docs cell
end
for i = 1:numel(docs)
    d = docs{i};
    if ~isfield(d, 'files') || ~isfield(d.files, 'file_info') || isempty(d.files.file_info)
        continue;
    end
    fi = d.files.file_info;
    for a = 1:numel(fi)
        for b = 1:numel(fi(a).locations)
            fi(a).locations(b).delete_original = 0;
        end
    end
    d.files.file_info = fi;
    docs{i} = d;
end
end
