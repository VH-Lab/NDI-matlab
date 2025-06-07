function [genbanknames] = ndi_readGenBankNames(filename)
    % NDI_READGENBANKNAMES - read the GenBank names from the 'names.dmp' file
    %
    % GENBANK_NAMES = ndi.database.fun.readGenBankNames(FILENAME)
    %
    % Given a 'names.dmp' file from a GenBank taxonomy data dump,
    % this function produces a Matlab structure with the following fields:
    %
    % fieldname            | Description
    % -----------------------------------------------------------------
    % genbank_commonname   | The genbank common name of the organism
    %                      |   (cell array of strings, 1 entry per node)
    %                      |   genbank_commonname{i} is the entry for node i.
    % scientific_name      | The genbank scientific name
    %                      |   (cell array of strings, 1 entry per node)
    %                      |   scientific_name{i} is the entry for node i.
    % synonym              | A cell array of strings with scientific name synonyms
    %                      |   (cell array of strings, potentially many entries per node)
    %                      |   synonym{i}{j} is the jth synonym for node i
    % other_commonname     | A cell array of strings with the other common names
    %                      |   (cell array of strings, potentially many entries per node)
    %                      |   other_commonname{i}{j} is the jth other common name for node i

    if ischar(filename)
        T = vlt.file.text2cellstr(filename);
    else
        T = filename; % hidden mode for debugging
    end

    mystr = split(T{end},sprintf('\t|\t'));
    maxnode = eval(mystr{1});

    genbank_commonname = cell(maxnode,1);
    scientific_name = cell(maxnode,1);
    synonym = cell(maxnode,1);
    other_commonname = cell(maxnode,1);

    progressbar('Interpreting node names...');

    for t=1:numel(T)

        if mod(t,1000) == 0
            progressbar(t/numel(T));
        end

        mystr = split(T{t},sprintf('\t|\t'));
        % remove tab and line at end of line
        lasttab = strfind(mystr{end},sprintf('\t|'));
        if ~isempty(lasttab)
            mystr{end} = mystr{end}(1:lasttab-1);
        end
        node_here = eval(mystr{1});
        name_here = mystr{2};
        category = mystr{end};

        switch category
            case 'scientific name'
                if ~isempty(scientific_name{node_here})
                    error(['Multiply scientific names for node ' num2str(node_here) '.']);
                end
                scientific_name{node_here} = name_here;
            case 'synonym'
                if isempty(synonym{node_here})
                    synonym{node_here} = {};
                end
                synonym{node_here}{end+1} = name_here;
            case 'genbank common name'
                if ~isempty(genbank_commonname{node_here})
                    error(['Multiply genbank common names for node ' num2str(node_here) '.']);
                end
                genbank_commonname{node_here} = name_here;
            case 'common name'
                if isempty(other_commonname{node_here})
                    other_commonname{node_here} = {};
                end
                other_commonname{node_here}{end+1} = name_here;

            otherwise
                % do nothing
        end
    end

    progressbar(1);

    genbanknames = vlt.data.var2struct('genbank_commonname','scientific_name','synonym','other_commonname');
