% this is a manual test

S = ndi.session.dir('/Users/vanhoosr/test/2019-11-19');

p_visstim = S.getprobes('name','vhvis_spike2','reference',1);
p_visstim = p_visstim{1};

p_ctx = S.getprobes('name','carbonfiber');
p_ctx = p_ctx{1};

[data,t,timeref_ctx] = p_ctx.readtimeseries(1,0,100);

figure(100);
plot(t,data(:,1));
xlabel('Time(s)');
ylabel('Voltage(V)');
set(gca,'xlim',[t(1) t(end)]);
box off;

[data2,t2,timeref_stim]=p_visstim.readtimeseries(timeref_ctx,-Inf,Inf); % read all data from epoch 1 of p_ctx1 !

figure(100);
hold on;
vlt.neuro.stimulus.plot_stimulus_timeseries(7,t2.stimon,t2.stimon+2,'stimid',data2.stimid);

