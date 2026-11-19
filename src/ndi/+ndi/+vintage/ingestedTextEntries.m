function out = ingestedTextEntries(mode, x)
%INGESTEDTEXTENTRIES An unpacked text channel's entries, to and from the bytes of its body.
%
%   BYTES = ndi.vintage.ingestedTextEntries('encode', ENTRIES) is the content
%   of the `sampled_body` member that holds an unpacked text channel's
%   entries; ENTRIES = ndi.vintage.ingestedTextEntries('decode', BYTES) reads
%   it back.
%
%   Decided by Jess Haley, 2026-11-19 [text channel entries are a JSON array]
%   (did-schema docs/plans/did_v2_standing_wiring_plan.md): "an unpacked text
%   channel's times are an uncompressed array of 64-bit floats, as for events
%   ([unpacked event bodies are uncompressed]); its entries are one
%   uncompressed UTF-8 JSON array of strings in the same order, format EDAM
%   format_3464 "JSON"".
%
%     ENTRIES  a cell of character rows, one per event, in event order: what
%              ndi.compress.expand_eventmarktext gives for a text channel
%              (ndi.compress.vector2eventmarktext builds each entry as a
%              row); 'decode' returns a 1xN cell, each entry a 1xK char
%              (an empty entry 1x0, as the expander gives it)
%     BYTES    uint8 row: the JSON array (jsonencode), encoded as UTF-8
%
%   'encode' raises NDI:vintage:ingestedTextEntries:notText when an entry is
%   not a character array. ndi.migrate.internal.ingestedArchiveBodies
%   unpacks a text channel only when 'decode' of its 'encode' gives every
%   entry back exactly, so an entry the encoding cannot hold (a lone UTF-16
%   surrogate) leaves the events file packed, counted.
%
%   See also ndi.vintage.ingestedEventData, ndi.vintage.ingestedEventsRead.

arguments
    mode (1,:) char {mustBeMember(mode, {'encode', 'decode'})}
    x
end

switch mode
    case 'encode'
        if ~iscell(x) || ~all(cellfun(@(e) ischar(e) || (isstring(e) && isscalar(e)), x))
            error('NDI:vintage:ingestedTextEntries:notText', ...
                'A text channel''s entries must be a cell of character arrays.');
        end
        c = cellfun(@(e) reshape(char(e), 1, []), reshape(x, 1, []), 'UniformOutput', false);
        if isempty(c)
            txt = '[]';
        else
            % jsonencode writes a cell of character rows as a JSON array of
            % strings (a 1x1 cell too)
            txt = jsonencode(c);
        end
        out = unicode2native(txt, 'UTF-8');
        out = reshape(uint8(out), 1, []);
    case 'decode'
        txt = native2unicode(reshape(uint8(x), 1, []), 'UTF-8');
        v = jsondecode(txt);
        if ischar(v)
            v = {v};
        elseif isempty(v) && ~iscell(v)
            v = {};
        end
        if ~iscell(v) || ~all(cellfun(@ischar, v))
            error('NDI:vintage:ingestedTextEntries:notText', ...
                'The body does not hold a JSON array of strings.');
        end
        out = cellfun(@(e) reshape(e, 1, []), reshape(v, 1, []), 'UniformOutput', false);
end
end
