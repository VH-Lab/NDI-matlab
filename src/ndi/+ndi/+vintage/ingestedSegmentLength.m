function n = ingestedSegmentLength(S, A, series, nsamples)
%INGESTEDSEGMENTLENGTH Samples per v1 segment file of one ingested series, from its v2 body.
%
%   N = ndi.vintage.ingestedSegmentLength(SESSION, A, SERIES, NSAMPLES) for
%   an archive A (ndi.vintage.ingestedArchive) and a series name SERIES
%   ('ai_group1_seg.nbf_#') of an epoch of NSAMPLES samples:
%
%     a sampled_body   its time dimension's `chunk`: Decided by Jess Haley,
%                      2026-10-29 [segment length is the time chunk] ("an
%                      NDI segment length (v1 ...sample_analog_segment /
%                      sample_digital_segment, which NDI's reader uses to
%                      find a sample's segment file ...) is the time
%                      dimension's `chunk` on the data body")
%     an opaque_body   (pass 1's carried series, not converted) the length
%     with no chunk    of its first member when it has more than one: the
%                      v1 ingest cuts every segment but the last at the
%                      segment length; with one member, NSAMPLES (the whole
%                      epoch is that one segment)
%     no body          NSAMPLES (an evenly spaced time series, which is
%                      computed, not read)
%
%   See also ndi.vintage.ingestedArchive, ndi.daq.reader.mfdaq.

arguments
    S
    A (1,1) struct
    series (1,:) char
    nsamples (1,1) double
end

n = nsamples;
if ~isKey(A.bodies, series)
    return;
end
b = A.bodies(series);
if ~isempty(b.chunk) && isfinite(b.chunk) && b.chunk > 0
    n = double(b.chunk);
    return;
end
if b.members <= 1
    return;
end
% the first member's length
first = regexprep(series, '#$', '1');
[tname, stem] = ndi.vintage.ingestedArchiveFile(S, A, first, '.nbf.tgz');
c = onCleanup(@() deleteIfThere(tname));
switch series(1:2)
    case {'ai', 'ao', 'ax'}
        data = ndi.compress.expand_ephys(stem);
    case {'di', 'do'}
        data = ndi.compress.expand_digital(stem);
    case 'ti'
        data = ndi.compress.expand_time(stem);
    otherwise
        return;
end
n = size(data, 1);
end

function deleteIfThere(f)
if isfile(f); delete(f); end
end
