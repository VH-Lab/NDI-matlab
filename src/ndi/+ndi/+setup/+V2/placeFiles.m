function report = placeFiles(links, texts, options)
%PLACEFILES Put a session's recordings and small text files in its folder.
%
%   REPORT = ndi.setup.V2.placeFiles(LINKS, TEXTS) makes each LINKS(k).target
%   a HARD LINK to LINKS(k).source and writes each TEXTS(k).text to
%   TEXTS(k).file, creating folders as needed. Raw data is never copied and
%   never written to (Haley decisions #21, #32): a hard link is a second name
%   for the same bytes, so it costs no space and survives the session folder
%   being moved, but both names must be on ONE volume. When they are not,
%   this errors (ndi:setup:V2:crossVolume) rather than copying.
%
%   A target that already exists is left alone when it is the same size as
%   its source (counted as `existing`), and is an error otherwise.
%
%   Options:
%     'Verbose'  default true: print the denominator
%
%   REPORT fields: links, linked, existing, texts, written.

arguments
    links struct
    texts struct
    options.Verbose (1,1) logical = true
end

report = struct('links', numel(links), 'linked', 0, 'existing', 0, ...
    'texts', numel(texts), 'written', 0);
for k = 1:numel(links)
    src = links(k).source;
    dst = links(k).target;
    if ~isfile(src)
        error('ndi:setup:V2:noSource', 'No file to link: %s.', src);
    end
    if isfile(dst)
        a = dir(src); b = dir(dst);
        if a.bytes ~= b.bytes
            error('ndi:setup:V2:targetExists', ...
                '%s exists and is not %s (%d vs %d bytes).', dst, src, b.bytes, a.bytes);
        end
        report.existing = report.existing + 1;
        continue;
    end
    folder = fileparts(dst);
    if ~isfolder(folder)
        mkdir(folder);
    end
    if ispc
        [status, msg] = system(sprintf('mklink /H "%s" "%s"', dst, src));
    else
        [status, msg] = system(sprintf('ln "%s" "%s"', src, dst));
    end
    if status ~= 0
        error('ndi:setup:V2:crossVolume', ...
            ['Could not hard-link %s to %s (%s). A hard link needs both on one ' ...
             'volume; put the output folder on the same disk as the raw data. ' ...
             'Nothing is copied instead.'], dst, src, strtrim(msg));
    end
    report.linked = report.linked + 1;
end
for k = 1:numel(texts)
    folder = fileparts(texts(k).file);
    if ~isfolder(folder)
        mkdir(folder);
    end
    fid = fopen(texts(k).file, 'w');
    if fid < 0
        error('ndi:setup:V2:cannotWrite', 'Cannot write %s.', texts(k).file);
    end
    fwrite(fid, texts(k).text, 'char');
    fclose(fid);
    report.written = report.written + 1;
end
if options.Verbose
    fprintf(['DENOMINATOR: %d link(s) asked for: %d linked, %d already there; ' ...
        '%d text file(s) written of %d\n'], report.links, report.linked, ...
        report.existing, report.written, report.texts);
end
end
