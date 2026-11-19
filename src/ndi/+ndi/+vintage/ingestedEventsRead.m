function [channeltype, channel, T, D] = ingestedEventsRead(S, A)
%INGESTEDEVENTSREAD Every unpacked event, marker and text channel of a migrated ingested epoch, read.
%
%   [CHANNELTYPE, CHANNEL, T, D] = ndi.vintage.ingestedEventsRead(SESSION, A)
%   reads the channels of A.events (ndi.vintage.ingestedArchive; found by
%   ndi.vintage.ingestedEventChannels) as ndi.compress.expand_eventmarktext
%   returns a v1 `evmktx` file: CHANNELTYPE a cellstr of channel types,
%   CHANNEL their numbers, T and D cells of each channel's timestamps and
%   data (ndi.vintage.ingestedEventData). T is in seconds from the epoch's
%   start, as stored; the caller adds the start.
%
%   Each body is read as written by ndi.migrate.internal.ingestedArchiveBodies
%   ([unpacked event bodies are uncompressed], Jess Haley, 2026-11-17: "event
%   times and numeric codes as little-endian 64-bit floats, format EDAM
%   "binary", with no compression block"): member body_data_0, its values in
%   the order of the body's dimensions (`data.datum_order` 'F', the first
%   dimension fastest, when it has two). A text channel's entries are one
%   UTF-8 JSON array of strings ([text channel entries are a JSON array],
%   Jess Haley, 2026-11-19), read by ndi.vintage.ingestedTextEntries.
%
%   Raises NDI:daq:reader:ingestedFileNotFound when a channel's body is
%   missing.
%
%   See also ndi.vintage.ingestedEventChannels, ndi.vintage.ingestedEventData.

E = A.events;
channeltype = cell(1, numel(E));
channel = zeros(1, numel(E));
T = cell(1, numel(E));
D = cell(1, numel(E));
for k = 1:numel(E)
    if isempty(E(k).times) || isempty(E(k).values)
        error('NDI:daq:reader:ingestedFileNotFound', ...
            'Epoch %s: the %s channel %d (observation %s) has no data body.', ...
            A.epoch_id, E(k).type, E(k).number, E(k).statement_id);
    end
    times = readNumbers(S, E(k).times);
    codes = [];
    if strcmp(E(k).type, 'text')
        codes = ndi.vintage.ingestedTextEntries('decode', readBytes(S, E(k).values));
    elseif ~strcmp(E(k).type, 'event')
        codes = readNumbers(S, E(k).values);
    end
    channeltype{k} = E(k).type;
    channel(k) = E(k).number;
    [T{k}, D{k}] = ndi.vintage.ingestedEventData(E(k).type, times, codes);
end
end

function bytes = readBytes(S, doc)
f = S.database_openbinarydoc(doc, 'body_data_0');
bytes = f.fread(Inf, 'uint8');
S.database_closebinarydoc(f);
bytes = uint8(bytes(:)');
end

function x = readNumbers(S, doc)
bytes = readBytes(S, doc);
x = typecast(bytes, 'double');
[~, ~, endian] = computer();
if endian == 'B'; x = swapbytes(x); end
x = x(:);
p = doc.document_properties;
dims = {};
if isfield(p, 'data') && isstruct(p.data) && isfield(p.data, 'dimensions')
    dims = p.data.dimensions;
    if isstruct(dims); dims = num2cell(dims); end
end
if numel(dims) == 2
    n1 = double(dims{1}.n); n2 = double(dims{2}.n);
    if n1 * n2 == numel(x)
        x = reshape(x, n1, n2);
    end
end
end
