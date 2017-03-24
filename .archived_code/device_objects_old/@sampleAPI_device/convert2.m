%t_d1 = alpha * (t_d2 - tshift)  (alpha should be nearly 1) (or, if they weren't recorded at the same time, you'll get NaN

%calculate the alpha and intervals
%%[alpha,tshift] = sync(D1,interval#, D2,interval#)

%%[D2_inverval, D2_time,info] = convert(D1, (interval 2), (time tD1))
%function details
%it will either give the D2_interval and time that corresponds
%OR it will return empty if no such information exists
%info will be '1' if exact, '2' if approximate
%D1_intervals = [ 5 100 ; 110 57 ; 200 58; 300 400];
%D2_intervals = [ NaN 50 ; NaN 30 ; NaN 60 ; NaN 150];
%tshift = 10;
%alpha = 0.9;
function [D2_calculated_interval, D2_time,info] = NSD_convert(D1, D1_interval, t_d1, D2)

%D1_intervals = NSD_getintervals(D1);
D2_intervals = NSD_getintervals(D2);

for i=1:size(D2_intervals,1),
    [tshift,alpha,info] = NSD_timeshift(D1, D2, D1_interval, i);
    if info<3,  % got a match
        D2_calculated_interval = i;
        D2_time = alpha*t_d1 - tshift;
        return;
    end;
end;

epoch_number = 1;
start_time = 1;
duration = 2;
D2_start_time = [];
D2_calculated_interval = [];
[nrow,ncol] = size(D2_intervals);
if tshift >= 0 
    info = 1;
    while (epoch_number <= nrow),
        if isnan(D2_intervals(epoch_number,start_time)) % predict starting time for D2;
            D2_duration = D2_intervals(epoch_number,duration);
            D2_start_time = [D2_start_time (D1_intervals(epoch_number,start_time)/alpha+tshift)];
            D2_calculated_interval = [D2_calculated_interval D1_intervals(epoch_number,start_time)/alpha+tshift+D2_duration];
        end
    epoch_number = epoch_number +1;
    end
end
end



