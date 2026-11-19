function [T, D] = ingestedEventData(type, times, codes)
%INGESTEDEVENTDATA An unpacked event, marker or text channel's values, as NDI's event reader returns them.
%
%   [T, D] = ndi.vintage.ingestedEventData(TYPE, TIMES, CODES) gives the
%   timestamps T and data D that ndi.compress.expand_eventmarktext returned
%   for one channel of a v1 `evmktx_group<g>_seg.nbf_1` file, from the
%   channel's unpacked values ([event channels are time-valued observations],
%   Jess Haley, 2026-11-17):
%
%     TYPE    'event', 'marker' or 'text'
%     TIMES   the event times, as stored: seconds from the epoch's start
%     CODES   a marker channel's codes (one row per event); a text channel's
%             entries (a cell of character arrays, one per event, as
%             ndi.vintage.ingestedTextEntries decodes them); [] for an event
%             channel
%
%   T is TIMES as a column; D is a column of ones for an event channel (one
%   per event, as NDI's readers mark an event), CODES for a marker channel,
%   and for a text channel the entries as a 1xN cell of character rows, the
%   shape NDI-compress's expander gives (ndi.compress.vector2eventmarktext;
%   Decided by Jess Haley, 2026-11-19 [text channel entries are a JSON
%   array]). The epoch's start is added by the caller (the reader adds the
%   start its time reference states; ndi.daq.reader.mfdaq).
%
%   ndi.migrate.internal.ingestedArchiveBodies unpacks a file only when this
%   gives back, for every channel, exactly what NDI's expander read from it
%   ([unpacked events file is removed]: "An archive whose file the round trip
%   cannot rebuild exactly is not unpacked"), so the reader and the second
%   pass use this one rule. Any other TYPE is an error.
%
%   See also ndi.vintage.ingestedEventChannels, ndi.vintage.ingestedEventsRead.

arguments
    type (1,:) char
    times
    codes = []
end

T = double(times(:));
switch type
    case 'event'
        D = ones(numel(T), 1);
    case 'marker'
        D = double(codes);
        if isvector(D); D = D(:); end
    case 'text'
        if isempty(codes); codes = {}; end
        D = cellfun(@(e) reshape(char(e), 1, []), reshape(codes, 1, []), 'UniformOutput', false);
    otherwise
        error('NDI:daq:reader:ingestedEventType', ...
            'An unpacked %s channel is not read here: only event, marker and text channels are unpacked.', ...
            type);
end
end
