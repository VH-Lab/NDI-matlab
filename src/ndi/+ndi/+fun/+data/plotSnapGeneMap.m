function [dna_sequence, featuresTable] = plotSnapGeneMap(filename)
% PLOTSNAPGENEMAP Extract DNA and features from a SnapGene .dna file.
%   [SEQ, TBL] = PLOTSNAPGENEMAP(FILENAME) parses the binary/XML SnapGene
%   format to return the DNA string and a detailed table of features.
%   If the Bioinformatics Toolbox is present, it also opens the 
%   Genomics Viewer with color-coded tracks.

    %% 1. Read and Parse SnapGene File
    fid = fopen(filename, 'r');
    if fid == -1, error('Cannot open file: %s', filename); end
    raw_cells = textscan(fid, '%s');
    fclose(fid);
    full_text = strjoin(raw_cells{1}, ' ');

    % Extract DNA Sequence
    dna_matches = regexp(full_text, '[atcgATCG]{100,}', 'match');
    if isempty(dna_matches), error('DNA sequence not found.'); end
    dna_sequence = upper(dna_matches{1});
    seqLen = length(dna_sequence);

    %% 2. Parse Features and Primers with Metadata
    f_blocks = regexp(full_text, '<Feature(.*?)</Feature>', 'tokens');
    p_blocks = regexp(full_text, '<Primer(.*?)</Primer>', 'tokens');
    all_blocks = [f_blocks, p_blocks];
    num_total = length(all_blocks);
    
    % Pre-allocate
    features = struct('Label', cell(num_total,1), 'Start', 0, 'End', 0, ...
                      'Type', '', 'Dir', '', 'Color', '', ...
                      'Tm', '', 'Translation', '', 'Notes', '');
    
    for i = 1:num_total
        b = all_blocks{i}{1};
        n = regexp(b, 'name="([^"]+)"', 'tokens');
        r = regexp(b, 'range="(\d+)-(\d+)"', 'tokens');
        t = regexp(b, 'type="([^"]+)"', 'tokens');
        c = regexp(b, 'color="([^"]+)"', 'tokens');
        d = regexp(b, 'directionality="(\d+)"', 'tokens');
        tr = regexp(b, 'translation"><V text="([^"]+)"', 'tokens');
        tm = regexp(b, 'meltingTemperature="(\d+)"', 'tokens');
        nt = regexp(b, '<V text="&lt;html&gt;(.*?)&lt;/html&gt;"', 'tokens');
        
        if ~isempty(n), features(i).Label = strtrim(regexprep(n{1}{1}, '"', ' ')); end
        if ~isempty(r), features(i).Start = str2double(r{1}{1}); features(i).End = str2double(r{1}{2}); end
        if ~isempty(t), features(i).Type = t{1}{1}; end
        if ~isempty(c), features(i).Color = c{1}{1}; end
        if ~isempty(tm), features(i).Tm = tm{1}{1}; end
        if ~isempty(tr), features(i).Translation = tr{1}{1}; end
        if ~isempty(d)
            if strcmp(d{1}{1},'1'), features(i).Dir = 'FWD'; else, features(i).Dir = 'REV'; end
        end
        if ~isempty(nt)
            % Strip HTML and clean special characters
            desc = regexprep(nt{1}{1}, '&lt;.*?&gt;', ''); 
            features(i).Notes = strtrim(desc);
        end
    end
    
    featuresTable = struct2table(features);
    featuresTable(featuresTable.Start == 0, :) = []; % Remove library ghosts
    featuresTable = sortrows(featuresTable, 'Start');

    %% 3. Conditional Plotting (Bioinformatics Toolbox Check)
    hasToolbox = license('test', 'Bioinformatics_Toolbox') && ~isempty(ver('bioinfo'));
    
    if hasToolbox
        refID = 'Plasmid';
        fastaFile = 'temp_plasmid.fasta';
        gffFile = 'temp_features.gff3';
        
        if exist(fastaFile, 'file'), delete(fastaFile); end
        if exist(gffFile, 'file'), delete(gffFile); end
        
        fastawrite(fastaFile, refID, dna_sequence);

            % Write GFF3 with advanced attributes
    gffFid = fopen(gffFile, 'w');
    fprintf(gffFid, '##gff-version 3\n');
    for i = 1:height(featuresTable)
        s = featuresTable.Start(i);
        e = featuresTable.End(i);
        if s <= 0, continue; end
        
        % Clean names and descriptions for GFF3 (escape special characters)
        cleanName = regexprep(featuresTable.Label{i}, '[^a-zA-Z0-9_]', '_');
        cleanNote = regexprep(featuresTable.Notes{i}, '[;=]', ''); 
        
        % Determine Strand (+ for FWD, - for REV)
        strand = '+';
        if strcmpi(featuresTable.Dir{i}, 'REV'), strand = '-'; end
        
        % Build the Attribute String (Column 9)
        attr = sprintf('ID=f%d;Name=%s;color=%s', i, cleanName, featuresTable.Color{i});
        if ~isempty(featuresTable.Translation{i})
            attr = sprintf('%s;product=%s', attr, featuresTable.Translation{i});
        end
        if ~isempty(featuresTable.Tm{i})
            attr = sprintf('%s;Tm=%s', attr, featuresTable.Tm{i});
        end
        if ~isempty(cleanNote)
            attr = sprintf('%s;Note=%s', attr, cleanNote);
        end

        % Write the full 9-column line
        % Col 7: Strand, Col 9: Extended Attributes
        fprintf(gffFid, '%s\tSnapGene\tCDS\t%d\t%d\t.\t%s\t.\t%s\n', ...
            refID, s, e, strand, attr);
    end
    fclose(gffFid);


        rehash;
        gv = genomicsViewer(ReferenceFile=fastaFile);
        addlistener(gv, 'ObjectBeingDestroyed', @(src, event) deleteLocalFiles(fastaFile, gffFile));
        addTracks(gv, gffFile);

        fprintf('Genomics Viewer launched.\n');
    else
        warning('Bioinformatics Toolbox not found. Data parsed but plot skipped.');
    end
end

function deleteLocalFiles(f1, f2)
    pause(0.5);
    if exist(f1, 'file'), delete(f1); end
    if exist(f2, 'file'), delete(f2); end
end
