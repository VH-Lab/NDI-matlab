function [g] = plot_extracellular_spikeshapes(S, space, g)
    % ndi.fun.plot_extracellular_spikeshapes - plot the extracellularly recorded neuron spike shapes
    %
    % G = ndi.fun.plot_extracellular_spikeshapes(S, space)
    %
    % Searches the experimental session S for documents of type 'neuron_extracellular',
    % and then plots the element names and their waveforms.
    % SPACE is the space between multichannel waveforms (in the same units as the spike
    % waveform).
    %

    if nargin<3,
        g = S.database_search(ndi.query('','isa','extracellular',''));
    end;

    %e = S.database_search(ndi.query('element.type','exact_string','spikes',''));

    f = figure;

    x_axis = [Inf -Inf];
    y_axis = [Inf -Inf];

    for i=1:numel(g),

        vlt.plot.supersubplot(f,4,4,i);
        cla;
        gi = g{i}.document_properties.neuron_extracellular;
        vlt.plot.plot_multichan(gi.mean_waveform,gi.waveform_sample_times,space);
        x_axis(1) = min(x_axis(1),min(gi.waveform_sample_times));
        x_axis(2) = max(x_axis(1),max(gi.waveform_sample_times));
        A = axis;
        y_axis = [min(A(3),y_axis(1)) max(A(4),y_axis(2))];


    end;

    for i=1:numel(g),
        vlt.plot.supersubplot(f,4,4,i);
        axis([x_axis y_axis]);
    end;
