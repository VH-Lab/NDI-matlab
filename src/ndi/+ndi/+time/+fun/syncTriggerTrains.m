function [shift, scale] = syncTriggerTrains(t1, t2, options)
% NDI.TIME.FUN.SYNCTRIGGERTRAINS - Synchronize clocks with drift and drop robustness
%
%   [SHIFT, SCALE] = NDI.TIME.FUN.SYNCTRIGGERTRAINS(T1, T2)
%   returns SHIFT and SCALE such that T2 = SHIFT + SCALE * T1.
%
%   This function aligns two independent clocks recording a common digital 
%   pulse train. It is engineered for high-precision electrophysiology 
%   within the NDI framework.
%
%   ALGORITHM:
%   1. Coarse Hashing: Uses quantized inter-pulse intervals (IPI) to find 
%      candidate alignment "seeds". The quantization is drift-tolerant.
%   2. Drift-Aware Global Validation: Tests each candidate offset. The 
%      matching window expands dynamically to account for uncorrected 
%      clock drift ($200ppm+$) across long files.
%   3. Robustness: Permits exactly one missing pulse in the match sequence.
%   4. Ambiguity Protection: Exhaustively tests all possible alignments and 
%      throws an error if multiple distinct valid mappings are found.
%
%   INPUTS:
%       t1: (Vector) Pulse onset times (seconds) from Device 1.
%       t2: (Vector) Pulse onset times (seconds) from Device 2.
%
%   OPTIONS (Name-Value arguments):
%       alignmentTolerance: (Default 0.005) Max allowable jitter (s).
%       minMatchRate:       (Default 0.8) Fraction of pulses that must align.
%       fingerprintSize:    (Default 5) Number of intervals per hash key.
%
%   OUTPUTS:
%       shift: Time intercept (s) for the mapping T2 = SHIFT + SCALE * T1.
%       scale: Clock drift ratio. Returns NaN if no match is found.
%
%   ERRORS:
%       'ndi:time:sync:ambiguous': Thrown if multiple distinct high-certainty 
%                                  alignments are discovered.

    arguments
        t1 (:,1) double
        t2 (:,1) double
        options.alignmentTolerance (1,1) double = 0.005 
        options.minMatchRate (1,1) double = 0.8
        options.fingerprintSize (1,1) double = 5
    end

    shift = NaN; scale = NaN;
    fSize = options.fingerprintSize;

    % Pre-check: Minimum pulses required to form a fingerprint
    if length(t1) < fSize || length(t2) < fSize, return; end

    % Standardize direction: Target is the longer recording (by count)
    % runRobustGlobalSync(target, prober) returns target = shift + scale * prober
    % We want T2 = shift + scale * T1, so:
    if length(t1) >= length(t2)
        % runRobustGlobalSync(t1, t2) gives t1 = s_raw + m_raw * t2
        % Invert: t2 = (1/m_raw)*t1 - s_raw/m_raw
        [s_raw, m_raw] = runRobustGlobalSync(t1, t2, options);
        if ~isnan(s_raw)
            scale = 1 / m_raw;
            shift = -s_raw / m_raw;
        end
    else
        % runRobustGlobalSync(t2, t1) gives t2 = shift + scale * t1 directly
        [shift, scale] = runRobustGlobalSync(t2, t1, options);
    end
end

function [shift, scale] = runRobustGlobalSync(target, prober, options)
    shift = NaN; scale = NaN;
    tol = options.alignmentTolerance;
    fSize = options.fingerprintSize;
    
    % 1. Build Interval Hash Map for Target
    % Quantization is set to 2*tol to ensure clock drift (~200ppm) 
    % doesn't shift the IPI into the wrong bucket immediately.
    dt_target = diff(target);
    q_target = round(dt_target ./ (tol * 2)); 
    mapObj = containers.Map('KeyType', 'char', 'ValueType', 'any');
    
    for i = 1:(length(q_target) - fSize + 1)
        key = sprintf('%d,', q_target(i:i+fSize-1));
        if isKey(mapObj, key)
            mapObj(key) = [mapObj(key), i];
        else
            mapObj(key) = i;
        end
    end

    % 2. Identify Potential Hypothesis Offsets
    dt_prober = diff(prober);
    q_prober = round(dt_prober ./ (tol * 2));
    potentialOffsets = []; 

    for i = 1:(length(q_prober) - fSize + 1)
        searchKey = sprintf('%d,', q_prober(i:i+fSize-1));
        if isKey(mapObj, searchKey)
            idx_targets = mapObj(searchKey);
            potentialOffsets = unique([potentialOffsets; idx_targets(:) - i]);
        end
    end

    % 3. Global Validation Loop
    results = struct('shift', {}, 'scale', {}, 'score', {});

    for offset = potentialOffsets'
        % Determine rough starting shift from the seed pulse
        idx_p_seed = max(1, 1 - offset);
        idx_t_seed = idx_p_seed + offset;
        if idx_t_seed > length(target) || idx_t_seed < 1, continue; end
        roughShift = target(idx_t_seed) - prober(idx_p_seed);
        
        matched_p = []; matched_t = [];
        missedCount = 0;
        
        % Validate this offset across the entire prober train
        % We use a dynamic window: tol * 5 + 0.1% of elapsed time
        % This ensures drift doesn't cause rejection before the polyfit.
        for i = 1:length(prober)
            expected_t = prober(i) + roughShift;
            [val, t_idx] = min(abs(target - expected_t));
            
            % Threshold grows with distance from seed to accommodate drift
            dist_from_seed = abs(prober(i) - prober(idx_p_seed));
            dynamic_tol = max(tol * 5, dist_from_seed * 0.001); 
            
            if val <= dynamic_tol
                matched_p(end+1) = prober(i); %#ok<AGROW>
                matched_t(end+1) = target(t_idx); %#ok<AGROW>
            else
                missedCount = missedCount + 1;
            end
        end
        
        rate = length(matched_p) / length(prober);
        
        % Accept hypothesis if match rate is high and drops are minimal
        if rate >= options.minMatchRate && missedCount <= 1
            model = polyfit(matched_p, matched_t, 1);
            results(end+1).shift = model(2); %#ok<AGROW>
            results(end).scale = model(1); %#ok<AGROW>
            results(end).score = rate; %#ok<AGROW>
        end
    end

    if isempty(results), return; end
    
    % Sort by match rate (highest first)
    [~, sIdx] = sort([results.score], 'descend');
    results = results(sIdx);
    
    % 4. Multi-offset Ambiguity Check
    if length(results) > 1
        % Filter out identical shifts; only error if truly distinct offsets compete
        best_s = results(1).shift;
        for k = 2:length(results)
            if abs(results(k).shift - best_s) > (tol * 10)
                if results(k).score > 0.8 * results(1).score
                    error('ndi:time:sync:ambiguous', ...
                        'Ambiguity: Found %d distinct global alignments. Data is too periodic.', ...
                        length(results));
                end
            end
        end
    end

    % Return the highest scoring verified model
    shift = results(1).shift;
    scale = results(1).scale;
end