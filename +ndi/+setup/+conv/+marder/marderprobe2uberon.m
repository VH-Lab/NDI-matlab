function d = marderprobe2uberon(S)
    %
    % D = MARDERPROBE2UBERON(S)
    %
    % Add probe_location information based on Marder probe data.
    %

    p = S.getprobes('type','n-trode');
    p1 = S.getprobes('type','sharp-Vm');
    p2 = S.getprobes('type','sharp-Im');
    p3 = S.getprobes('type','ppg');
    p = cat(1,p,p1,p2,p3);

    filepath = fileparts(mfilename('fullpath'));

    t = readtable([filepath filesep 'marderprobe2uberontable.txt'],'delimiter','\t');

    d = {};

    for i=1:numel(p),
        index = find(strcmp(p{i}.name,t.("probe")));
        if ~isempty(index),
            disp(['Found entry for ' p{i}.name '...']);
            ontol = ndi.database.fun.uberon_ontology_lookup('Name',t{index,"name"}{1});
            if isempty(ontol),
                error(['Could not find entry ' char(t{index,"name"}{1}) '.']);
            end;
            identifier = ['UBERON:' int2str(ontol(1).Identifier)];
            pl.ontology_name = identifier;
            pl.name = t{index,"name"}{1};
            d_here = ndi.document('probe_location','probe_location',pl) + S.newdocument();
            d_here = d_here.set_dependency_value("probe_id",p{i}.id());
            d{end+1} = d_here;
        end;
    end;
