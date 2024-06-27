function h = multichan(data,t,space)
% MULTICHAN - Plots multiple channels
%
%  H = ndi.fun.plot.multichan(DATA,T,SPACE)
%
%  Plots multiple channels of DATA (assumed to be NUMSAMPLES X NUMCHANNELS)
%
%  T is the time for each sample and SPACE is the space to put between channels.
%

for i=1:size(data,2),
	if i~=1,
		hold on;
	end;
	h(i) = plot(t,(i-1)*space+data(:,i),'color',[0.7 0.7 0.7]);
	
end;
