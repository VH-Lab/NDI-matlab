function nchan = channelCount(probe, epoch)
% NDI.FUN.PROBE.CHANNELCOUNT - number of channels a probe's epochprobemap assigns to it
%
% NCHAN = NDI.FUN.PROBE.CHANNELCOUNT(PROBE)
% NCHAN = NDI.FUN.PROBE.CHANNELCOUNT(PROBE, EPOCH)
%
% Returns the number of channels the epochprobemap assigns to PROBE, read from its
% channel list (via getchanneldevinfo) without loading any sample data. EPOCH is an
% epoch number or epoch_id; by default the probe's first epoch is used (the channel
% count is normally the same across a probe's epochs).
%
% NCHAN is [] if it cannot be determined (e.g. the probe has no epochs or does not
% expose getchanneldevinfo).
%
% See also: NDI.FUN.PROBE.GEOMETRY.FROMSTRUCT, NDI.PROBE/GETCHANNELDEVINFO

    arguments
        probe
        epoch = []
    end

    nchan = [];
    try
        if isempty(epoch),
            et = probe.epochtable();
            if isempty(et),
                return;
            end;
            epoch = et(1).epoch_id;
        end;
        [~,~,~,~,channellist] = probe.getchanneldevinfo(epoch);
        nchan = numel(channellist);
    catch
        nchan = [];
    end
end
