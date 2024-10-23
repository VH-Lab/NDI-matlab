function t = samples2times(s,t0_t1,sr)
    % SAMPLES2TIMES - convert sample index numbers/sample numbers to sample times
    %
    % T = SAMPLES2TIMES(S, T0_T1, SR)
    %
    % Given the index numbers of samples in vector S, and a range of times in the recording
    % T0_T1 = [ T0 T1 ], and a fixed sample rate SR, calculate the time of each
    % sample S. S(i) is the sample index number of T(i).
    %
    %

    %s = 1 + (t-t0_t1(1))*sr
    %(s-1)/sr == (t-t0_t1(1))

    t = (s-1)/sr + t0_t1(1);

    g = (isinf(s) & s<0);
    t(g) = t0_t1(1);
    g = (isinf(s) & s>0);
    t(g) = t0_t1(2);

