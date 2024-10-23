function s = times2samples(t,t0_t1,sr)
    % TIMES2SAMPLES - convert sample times to sample index numbers / sample numbers
    %
    % S = TIMES2SAMPLES(T, T0_T1, SR)
    %
    % Given the times of samples in vector T, and a range of times in the recording
    % T0_T1 = [ T0 T1 ], and a fixed sample rate SR, calculate the index number of each
    % sample S. S(i) is the sample index number of T(i).
    %
    %

    s = 1 + round( (t-t0_t1(1))*sr);

    g = (isinf(t) & t<0);
    s(g) = 1;
    g = (isinf(t) & t>0);
    s(g) = 1+sr*diff(t0_t1);

