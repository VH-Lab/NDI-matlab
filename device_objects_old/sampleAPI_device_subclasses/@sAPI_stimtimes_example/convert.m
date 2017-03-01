function t_ = convert(d,t,clock,sampleAPI_clock);

%t_ is examined with clock type and return the time interval in terms of
%the desired clock
interval = 1;

if strcmp (sampleAPI_clock.type, 'global'),
    
elseif strcmp (sampleAPI_clock.type, 'local'),
	t_ = d.clock(t);  %% local to local
    
    
elseif strcmp (sampleAPI_clock.type, 'interval-relative'),

    while (sampleAPI_clock(d, interval) + d(interval,1) < t)  %% if t is a interval relative time
        interval++;
        t_ = sampleAPI_clock(d, interval) + d(interval,1);
        t_ = d.timestart + t_;
    end
          
    
    % if t0 and t1 are local or global clock, one neeed to first find the interval
    % time between the two and also find the correspond interval time for
    % the relative interval
    
end;


