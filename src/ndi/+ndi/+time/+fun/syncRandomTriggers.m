function [shift, scale] = syncRandomTriggers(t1, t2, options)
% SYNCRANDOMTRIGGERS - Synchronize clocks using random digital triggers
%
%   [SHIFT, SCALE] = ndi.time.fun.syncRandomTriggers(T1, T2)
%   returns SHIFT and SCALE such that T1 = SHIFT + SCALE * T2.
%
%   This function aligns two devices that recorded the same stochastic 
%   event sequence (e.g., random TTL triggers) but on independent clocks.
%   It is optimized for very long recordings and partial temporal overlaps.
%
%   ALGORITHM:
%   1. Converts event times into a "rhythm" (inter-event intervals).
%   2. Builds a Hash Map (containers.Map) of interval sequences from the 
%      longer recording, enabling O(1) constant-time pattern lookups.
%   3. Probes the Map using fingerprints from the shorter recording in a 
%      randomly permuted order. Randomization ensures rapid discovery 
%      regardless of where the overlap occurs in the files.
%   4. Validates the first candidate match with a secondary pulse check 
%      and performs a linear regression to solve for SCALE and SHIFT.
%
%   INPUTS:
%       t1: (Vector) Transition times (seconds) from Device 1.
%       t2: (Vector) Transition times (seconds) from Device 2.
%
%   OPTIONS (Name-Value arguments):
%       alignmentTolerance: (Default 0.002) Maximum jitter (s) allowed
%                           between clocks to consider pulses a match.
%       fingerprintSize:    (Default 4) Number of intervals per hash key.
%
%   OUTPUTS:
%       shift: Time intercept (s) for the mapping T1 = SHIFT + SCALE * T2.
%       scale: Clock drift/ratio. Returns NaN if no match is found.
%
%   EXAMPLE:
%       [s, m] = ndi.time.fun.syncRandomTriggers(daq_times, cam_times);

    arguments
        t1 (:,1) double
        t2 (:,1) double
        options.alignmentTolerance (1,1) double = 0.002
        options.fingerprintSize (1,1) double = 4
    end

    shift = NaN; scale = NaN;
    fSize = options.fingerprintSize;

    % Pre-check: Ensure enough data exists to form at least one fingerprint
    if length(t1) <= fSize || length(t2) <= fSize
        return;
    end

    % 1. Determine which recording is longer to optimize the Hash Map
    % We hash the long file and probe with the short one for efficiency.
    dur1 = max(t1) - min(t1);
    dur2 = max(t2) - min(t2);

    if dur1 >= dur2
        % Target (Map) is t1, Prober is t2. Result: t1 = s*t2 + b
        [shift, scale] = runHashSync(t1, t2, options);
    else
        % Target (Map) is t2, Prober is t1. Result: t2 = s_inv*t1 + b_inv
        [s_inv, m_inv] = runHashSync(t2, t1, options);
        if ~isnan(s_inv)
            % Algebrically invert: t1 = (1/m_inv)*t2 - (s_inv/m_inv)
            scale = 1 / m_inv;
            shift = -s_inv / m_inv;
        end
    end
end

function [shift, scale] = runHashSync(target, prober, options)
    % Internal core: Hashes 'target' and probes with 'prober'
    shift = NaN; scale = NaN;
    fSize = options.fingerprintSize;
    
    dt_target = diff(target);
    dt_prober = diff(prober);
    
    % 2. Build Hash Table for Target (The "Database")
    % Quantization converts floating-point jitter into discrete "buckets"
    q_target = round(dt_target ./ options.alignmentTolerance);
    mapObj = containers.Map('KeyType', 'char', 'ValueType', 'double');

    for i = 1:(length(q_target) - fSize + 1)
        % Fingerprint is a sequence of fSize intervals (fSize+1 pulses)
        key = sprintf('%d,', q_target(i:i+fSize-1));
        if ~isKey(mapObj, key)
            mapObj(key) = i; 
        end
    end

    % 3. Probe with Prober (The "Searcher")
    q_prober = round(dt_prober ./ options.alignmentTolerance);
    num_possible_probes = length(q_prober) - fSize + 1;
    
    % MONTE CARLO OPTIMIZATION: 
    % Randomize search order to find overlap in O(1) expected time.
    search_order = randperm(num_possible_probes);
    
    for i = search_order
        searchKey = sprintf('%d,', q_prober(i:i+fSize-1));
        
        if isKey(mapObj, searchKey)
            % SEED MATCH FOUND
            idx_target = mapObj(searchKey);
            
            % Extract the matching pulse sequences
            p_target = target(idx_target : idx_target + fSize);
            p_prober = prober(i : i + fSize);
            
            % Initial regression on the fingerprint
            seedModel = polyfit(p_prober, p_target, 1);
            
            % 4. VERIFICATION: 
            % Check a pulse further in the sequence to rule out coincidental 
            % interval matches in very dense or repetitive datasets.
            if (i + fSize + 1 <= length(prober)) && (idx_target + fSize + 1 <= length(target))
                test_p_prob = prober(i + fSize + 1);
                test_p_target = target(idx_target + fSize + 1);
                if abs(test_p_target - polyval(seedModel, test_p_prob)) > options.alignmentTolerance
                    continue; % False positive: intervals matched but clocks diverged
                end
            end
            
            % Success: Return the model parameters
            scale = seedModel(1);
            shift = seedModel(2);
            return; 
        end
    end
end