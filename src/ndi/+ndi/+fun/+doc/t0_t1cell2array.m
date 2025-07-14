function t0t1_out = t0_t1cell2array(t0t1_in)
% T0_T1CELL2ARRAY - convert a t0..t1 interval expressed as a cell in an epochtable entry as array
%
% T0T1_OUT = t0_t1cell2array(T0T1_IN)
%
% Convert a t0_t1 entry from an epochtable (where it is a cell array of {[t0a t1a], [t0b t1b]} values
% to an array suitable for inclusion in an ndi.document object.
%
% Each t0t1 entry is converted to a column of a matrix. The first epochclock's t0t1 is represented
% as T0T1_OUT(1:2,1), the second as T0T1_OUT(1:2,2), etc.
%

arguments
	t0t1_in cell
end

t0t1_out = zeros(2,numel(t0t1_in));

for k=1:numel(t0t1_in)
    t0t1_out(1,k) = t0t1_in{1,k}(1);
    t0t1_out(2,k) = t0t1_in{1,k}(2);
end

