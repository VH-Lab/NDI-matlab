function E = epochbounds(probe, epochIds)
% NDI.FUN.PROBE.IMPORT.JRCLUST.EPOCHBOUNDS - epoch boundaries of a JRCLUST sort
%
% E = NDI.FUN.PROBE.IMPORT.JRCLUST.EPOCHBOUNDS(PROBE, EPOCHIDS)
%
% Rebuilds the boundaries of the concatenated sample stream that JRCLUST sorted.
% JRCLUST reads the epochs named in the parameter file's 'rawRecordings' one after
% another (see jrclust.detect.ndiRecording) and numbers its spikes 1..N across the
% whole stream, so mapping a spike back to an epoch means knowing how many samples
% each epoch contributed, in that order.
%
% EPOCHIDS is a cell array of epoch ids, in the order JRCLUST concatenated them.
% The sample count of each comes from the probe itself, the same way
% jrclust.detect.ndiRecording computes it (1+diff(times2samples(t0_t1))).
%
% Returns a struct E with fields:
%   epochIds     - the epoch ids, as given
%   counts       - [nEpochs x 1] number of samples each epoch contributed
%   bounds       - [nEpochs+1 x 1] cumulative sample counts, starting at 0. Epoch e
%                    holds the 1-based global samples in (bounds(e), bounds(e+1)].
%   totalSamples - bounds(end), the length of the concatenated stream
%   t0_t1        - {nEpochs x 1} each epoch's t0_t1 in its 'dev_local_time' clock
%   clock        - {nEpochs x 1} that ndi.time.clocktype
%
% Errors with identifier ndi:fun:probe:import:jrclust:probe:noSuchEpoch if an id is
% not an epoch of PROBE (the sort does not correspond to this probe), or
% ndi:fun:probe:import:jrclust:probe:noClock if an epoch has no 'dev_local_time'
% clock to store spike times in.
%
% See also: NDI.FUN.PROBE.IMPORT.JRCLUST.SPLITSPIKES,
%   NDI.FUN.PROBE.IMPORT.JRCLUST.PROBE

    arguments
        probe
        epochIds cell
    end

    et = probe.epochtable();
    allEpochIds = {et.epoch_id};

    nEpochs = numel(epochIds);

    E = struct();
    E.epochIds = epochIds;
    E.counts = zeros(nEpochs,1);
    E.t0_t1 = cell(nEpochs,1);
    E.clock = cell(nEpochs,1);

    for e=1:nEpochs,
        match = find(strcmp(epochIds{e}, allEpochIds),1);
        if isempty(match),
            error('ndi:fun:probe:import:jrclust:probe:noSuchEpoch', ...
                ['The sorted recording ''%s'' is not an epoch of probe %s. The sort ' ...
                'does not correspond to this probe.'], epochIds{e}, probe.elementstring());
        end;
        % the dev_local_time clock, in which spike times are stored
        found = 0;
        for c=1:numel(et(match).epoch_clock),
            if strcmp(et(match).epoch_clock{c}.type,'dev_local_time'),
                found = c; break;
            end;
        end;
        if ~found,
            error('ndi:fun:probe:import:jrclust:probe:noClock', ...
                'Epoch %s has no ''dev_local_time'' clock.', epochIds{e});
        end;
        E.clock{e} = et(match).epoch_clock{found};
        E.t0_t1{e} = et(match).t0_t1{found};
        ss = probe.times2samples(epochIds{e}, E.t0_t1{e});
        E.counts(e) = 1 + diff(ss); % matches jrclust.detect.ndiRecording
    end;

    E.bounds = [0; cumsum(E.counts)];
    E.totalSamples = E.bounds(end);

end % epochbounds()
