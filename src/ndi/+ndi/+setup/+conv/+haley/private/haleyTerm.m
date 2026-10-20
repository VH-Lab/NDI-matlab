function t = haleyTerm(name)
%HALEYTERM The decided ontology term for a name the Haley import writes.
%
%   T = haleyTerm(NAME) returns did2.build.term(NODE, LABEL) for NAME, a
%   handle the import's code uses: NODE the CURIE decided for it in the term
%   pass (Jess Haley, 2026-10-19) and the T19 review (2026-10-20), and LABEL
%   the term's name in DID-schema's term registry (schemas/
%   V_eta_term_registry.json), which is the ontology's own label. So
%   haleyTerm('mean') writes NCIT:C53319 'Arithmetic Mean'. The table below
%   holds every one of the registry's Haley terms, and TestTermRegistry checks
%   the two agree (tenet T19: a term is reused, not re-chosen).
%
%   A handle with no decided term is an error, so a misspelled or undecided
%   term is found when the import is built, not when the dataset is read.
%
%   NAME may be a cellstr or string array, giving a 1xN term array (a key's
%   positions).

arguments
    name {mustBeText}
end
persistent nodes
if isempty(nodes)
    nodes = termTable();
end
name = cellstr(name);
node = cell(size(name));
for k = 1:numel(name)
    if ~isKey(nodes, name{k})
        error('ndi:setup:conv:haley:undecidedTerm', ...
            'No decided term for "%s": add it to DID-schema''s term registry and haleyTerm''s table (tenet T19).', name{k});
    end
    e = nodes(name{k});
    node{k} = e{1};
    name{k} = e{2};
end
t = did2.build.term(node, name);
end

function m = termTable()
%TERMTABLE handle -> {CURIE, registry name}, grouped as the term pass decided them.
pairs = {
    % study, dataset, subjects, assertions
    'OD600',                                   'MCO:0000059',             'OD600'
    'bacteria growth duration after seeding',  'EMPTY:0000119',           'bacteria growth duration after seeding'
    'food availability',                       'ZECO:0000113',            'food availability'
    'fasting',                                 'ZECO:0000114',            'fasting'
    'organism strain',                         'NCIT:C14419',             'Organism Strain'
    'species',                                 'NCIT:C45293',             'Species'
    'accessibility',                           'NCIT:C175887',            'Open or Controlled Data Access Indicator'
    'unrestricted access',                     'NCIT:C183346',            'Unrestricted Access'
    'wild type',                               'NCIT:C62195',             'Wild Type'
    'mutant',                                  'NCIT:C25360',             'Mutant'
    'transgenic organism',                     'OBI:1000048',             'transgenic organism'
    'video recording',                         'NCIT:C91063',             'Video Recording'
    'inclusion in analysis',                   'EMPTY:0000314',           'inclusion in analysis'
    'diameter',                                'PATO:0001334',            'diameter'
    'spacing',                                 'NCIT:C45786',             'Spacing'
    'value basis',                             'EMPTY:0000298',           'value basis'
    'target',                                  'EMPTY:0000299',           'target'
    'intervalDuring',                          'time:intervalDuring',     'interval during'
    % manipulations, observations
    'ambient temperature',                     'NCIT:C90380',             'Environmental Temperature'
    'relative humidity',                       'om:RelativeHumidity',     'relative humidity'
    'location',                                'NCIT:C25341',             'Location'
    'image intensity',                         'NCIT:C221750',            'Imaging Signal Intensity'
    'culture medium',                          'OBI:0000079',             'culture medium'
    'bacterial patch volume',                  'EMPTY:0000120',           'bacterial patch volume'
    'bacterial OD600 (target) at seeding',     'EMPTY:0000105',           'bacterial OD600 (target) at seeding'
    % formulation types
    'LB medium, Lennox',                       'MCO:0000030',             'LB medium, Lennox'
    'LB with carbenicillin',                   'EMPTY:0000264',           'LB with carbenicillin'
    'nematode growth medium',                  'EMPTY:0000262',           'nematode growth medium'
    'nematode growth medium without peptone',  'EMPTY:0000263',           'nematode growth medium without peptone'
    'S basal',                                 'EMPTY:0000265',           'S basal'
    'S medium',                                'EMPTY:0000266',           'S medium'
    'trace metals solution',                   'MICRO:0000455',           'trace elements solution'
    'potassium phosphate buffer',              'EMPTY:0000329',           'potassium phosphate buffer'
    'potassium citrate solution',              'EMPTY:0000330',           'potassium citrate solution'
    'magnesium sulfate solution',              'EMPTY:0000267',           'magnesium sulfate solution'
    'calcium chloride solution',               'EMPTY:0000268',           'calcium chloride solution'
    'potassium phosphate monobasic solution',  'EMPTY:0000269',           'potassium phosphate monobasic solution'
    'potassium phosphate dibasic solution',    'EMPTY:0000270',           'potassium phosphate dibasic solution'
    'cholesterol solution',                    'EMPTY:0000271',           'cholesterol solution'
    % chemicals
    'water',                                   'CHEBI:15377',             'water'
    'agar',                                    'CHEBI:2509',              'agar'
    'sodium chloride',                         'CHEBI:26710',             'sodium chloride'
    'peptone',                                 'MICRO:0000178',           'peptone'
    'tryptone',                                'MICRO:0000182',           'tryptone'
    'yeast extract',                           'MICRO:0000201',           'yeast extract'
    'potassium dihydrogen phosphate',          'CHEBI:63036',             'potassium dihydrogen phosphate'
    'dipotassium hydrogen phosphate',          'CHEBI:131527',            'dipotassium hydrogen phosphate'
    'dipotassium hydrogen phosphate trihydrate', 'EMPTY:0000313',           'dipotassium hydrogen phosphate trihydrate'
    'magnesium sulfate',                       'CHEBI:32599',             'magnesium sulfate'
    'calcium chloride dihydrate',              'CHEBI:86158',             'calcium chloride dihydrate'
    'cholesterol',                             'CHEBI:16113',             'cholesterol'
    'ethanol',                                 'CHEBI:16236',             'ethanol'
    'citric acid monohydrate',                 'CHEBI:31404',             'Citric acid monohydrate'
    'tripotassium citrate monohydrate',        'CHEBI:64746',             'potassium citrate monohydrate'
    'disodium EDTA dihydrate',                 'CHEBI:64758',             'EDTA disodium salt dihydrate'
    'iron(II) sulfate heptahydrate',           'CHEBI:75836',             'iron(2+) sulfate heptahydrate'
    'manganese(II) chloride tetrahydrate',     'CHEBI:86368',             'manganese(II) chloride tetrahydrate'
    'zinc sulfate heptahydrate',               'CHEBI:32312',             'zinc sulfate heptahydrate'
    'copper(II) sulfate pentahydrate',         'CHEBI:31440',             'copper(II) sulfate pentahydrate'
    'carbenicillin',                           'CHEBI:3393',              'carbenicillin'
    % geometry, masks, tracks
    'brightfield imaging',                     'EMPTY:0000300',           'brightfield imaging'
    'brightfield microscopy',                  'NCIT:C19827',             'Brightfield Microscopy'
    'fluorescence microscopy',                 'NCIT:C16856',             'Fluorescence Microscopy'
    'video tracking',                          'EMPTY:0000301',           'video tracking'
    'moving average',                          'OBI:0200056',             'moving average'
    'distance transform',                      'EMPTY:0000302',           'distance transform'
    'image segmentation',                      'OBI:0003918',             'image segmentation'
    'image registration',                      'NCIT:C80145',             'Image Registration'
    'window',                                  'NCIT:C48921',             'Window'
    'interpolation method',                    'EMPTY:0000305',           'interpolation method'
    'linear interpolation',                    'EMPTY:0000306',           'linear interpolation'
    'maximum gap filled',                      'EMPTY:0000307',           'maximum gap filled'
    'arena diameter',                          'EMPTY:0000122',           'arena diameter'
    'position',                                'PATO:0000140',            'position'
    'speed',                                   'PATO:0000008',            'speed'
    'distance',                                'PATO:0000040',            'distance'
    'acceleration',                            'PATO:0001028',            'acceleration'
    'radius',                                  'PATO:0002390',            'radius'
    'circularity',                             'EMPTY:0000288',           'circularity'
    'overlap',                                 'NCIT:C54669',             'Overlap'
    'fraction',                                'NCIT:C25514',             'Fraction'
    'reference point',                         'NCIT:C45793',             'Reference Point'
    'nearest bacterial patch edge',            'EMPTY:0000276',           'nearest bacterial patch edge'
    'nearest bacterial patch',                 'EMPTY:0000297',           'nearest bacterial patch'
    'body part',                               'NCIT:C32221',             'Body Part'
    'head',                                    'UBERON:0000033',          'head'
    'body midpoint',                           'EMPTY:0000137',           'body midpoint'
    'tail',                                    'UBERON:0002415',          'tail'
    % E. coli
    'fluorescence intensity',                  'NCIT:C184706',            'Fluorescence Intensity'
    'normalization to background illumination', 'EMPTY:0000287',           'normalization to background illumination'
    'maximum',                                 'STATO:0000151',           'maximum observed value'
    'minimum',                                 'STATO:0000150',           'minimum observed value'
    'mean',                                    'NCIT:C53319',             'Arithmetic Mean'
    'median',                                  'NCIT:C28007',             'Median'
    'baseline',                                'NCIT:C25213',             'Baseline'
    'bacterial patch edge',                    'EMPTY:0000283',           'bacterial patch edge'
    'bacterial patch center',                  'EMPTY:0000284',           'bacterial patch center'
    'bacterial patch fluorescence peak',       'EMPTY:0000285',           'bacterial patch fluorescence peak'
    'distance end point',                      'EMPTY:0000286',           'distance end point'
    'bin width',                               'EMPTY:0000308',           'bin width'
    % encounters
    'encounter onset time',                    'EMPTY:0000140',           'encounter onset time'
    'encounter',                               'NCIT:C62143',             'Encounter'
    'encounter detection',                     'EMPTY:0000303',           'encounter detection'
    'entity in contact',                       'EMPTY:0000275',           'entity in contact'
    'encounter period',                        'EMPTY:0000277',           'encounter period'
    'before the first encounter',              'EMPTY:0000278',           'before the first encounter'
    'during the encounter',                    'EMPTY:0000279',           'during the encounter'
    'after the encounter',                     'EMPTY:0000280',           'after the encounter'
    'peak speed before an event',              'EMPTY:0000272',           'peak speed before an event'
    'minimum speed after an event',            'EMPTY:0000273',           'minimum speed after an event'
    'time to slow down',                       'EMPTY:0000274',           'time to slow down'
    'reference time point',                    'NCIT:C82576',             'Reference Time Point'
    'analysis window start',                   'EMPTY:0000281',           'analysis window start'
    'analysis window end',                     'EMPTY:0000282',           'analysis window end'
    'ordinary least squares estimation',       'STATO:0000370',           'ordinary least squares estimation'
    'posterior probability',                   'STATO:0000703',           'posterior probability'
    'probability',                             'NCIT:C54154',             'Probability'
    'behavioral state',                        'EMPTY:0000289',           'behavioral state'
    'exploitation',                            'EMPTY:0000290',           'exploitation'
    'sensing',                                 'EMPTY:0000291',           'sensing'
    'encounter type',                          'EMPTY:0000292',           'encounter type'
    'exploit',                                 'EMPTY:0000293',           'exploit'
    'sample',                                  'EMPTY:0000294',           'sample'
    'search on patch',                         'EMPTY:0000295',           'search on patch'
    'search off patch',                        'EMPTY:0000296',           'search off patch'
    'classification',                          'NCIT:C25161',             'Classification'
    'cannot be determined',                    'NCIT:C179711',            'Cannot Be Determined'
    'Gaussian mixture model clustering',       'EMPTY:0000316',           'Gaussian mixture model clustering'
    'quadratic discriminant analysis',         'EMPTY:0000317',           'quadratic discriminant analysis'
    % fits and estimates
    'slope',                                   'STATO:0000656',           'slope'
    'intercept',                               'STATO:0000657',           'intercept'
    'coefficient of determination',            'STATO:0000564',           'coefficient of determination'
    'prediction from a fitted model',          'EMPTY:0000304',           'prediction from a fitted model'
    'linear regression',                       'STATO:0000108',           'linear regression for analysis of continuous dependent variable'
    'regression coefficient',                  'STATO:0000565',           'regression coefficient'
    'relative cell density',                   'EMPTY:0000322',           'relative cell density'
    'normalization data transformation',       'OBI:0200169',             'normalization data transformation'
    'normalization reference value',           'EMPTY:0000323',           'normalization reference value'
    'lower limit of reported value',           'EMPTY:0000324',           'lower limit of reported value'
    % masks, plates, development (decided with Jess 2026-10-20)
    'acclimation plate',                       'EMPTY:0000319',           'acclimation plate'
    'food deprivation plate',                  'EMPTY:0000320',           'food deprivation plate'
    'assay plate',                             'EMPTY:0000321',           'assay plate'
    'developmental stage',                     'NCIT:C43531',             'Developmental Stage'
    'L4 larva Ce',                             'WBls:0000038',            'L4 larva Ce'
    'visual inspection',                       'NCIT:C214703',            'Visual Inspection'
    % keys, coordinates, units
    'video frame',                             'EMPTY:0000309',           'video frame'
    'coordinate',                              'NCIT:C44465',             'Coordinate'
    'X-coordinate',                            'NCIT:C44477',             'X-Coordinate'
    'Y-coordinate',                            'NCIT:C44478',             'Y-Coordinate'
    'x-axis',                                  'STATO:0000006',           'x-axis'
    'y-axis',                                  'STATO:0000008',           'y-axis'
    'image upper-left corner',                 'EMPTY:0000310',           'image upper-left corner'
    'image right',                             'EMPTY:0000311',           'image right'
    'image down',                              'EMPTY:0000312',           'image down'
    'meter',                                   'om:metre',                'metre'
    'liter',                                   'om:litre',                'litre'
    'second',                                  'om:second-Time',          'second'
    'minute',                                  'om:minute-Time',          'minute'
    'hour',                                    'om:hour',                 'hour'
    'meter per second',                        'om:metrePerSecond-Time',  'metre per second'
    'meter per second squared',                'om:metrePerSecond-TimeSquared', 'metre per second squared'
    'pixel',                                   'NCIT:C48367',             'Pixel'
    'frame',                                   'EMPTY:0000260',           'frame'
    'arbitrary unit per millisecond',          'EMPTY:0000261',           'arbitrary unit per millisecond'
    % masks and encounters (tenet T19, Jess Haley 2026-10-20)
    'binary mask',                             'NCIT:C201530',            'Binary Mask'
    'region of interest',                      'NCIT:C85402',             'Imaging Region of Interest'
    'bacterial patch',                         'EMPTY:0000325',           'bacterial patch'
    'sample type',                             'NCIT:C210102',            'Sample Type'
    'petri dish',                              'NCIT:C96141',             'Petri Dish'
    'arena',                                   'EMPTY:0000326',           'arena'
    'reference mark',                          'EMPTY:0000327',           'reference mark'
    'encountered entity',                      'EMPTY:0000328',           'encountered entity'
    % procedures, transfer settings, encounter thresholds (tenet T19 node pass,
    % Jess Haley 2026-10-20, decision #106)
    'seeding',                                 'EMPTY:0000331',           'seeding'
    'pouring',                                 'EMPTY:0000332',           'pouring'
    'incubation',                              'EMPTY:0000333',           'incubation'
    'refrigeration',                           'EMPTY:0000334',           'refrigeration'
    'ambient exposure',                        'EMPTY:0000335',           'ambient exposure'
    'agar plug transfer',                      'EMPTY:0000336',           'agar plug transfer'
    'worm picking',                            'EMPTY:0000337',           'worm picking'
    'eyelash picking',                         'EMPTY:0000338',           'eyelash picking'
    'cleaning step',                           'EMPTY:0000339',           'cleaning step'
    'droplet',                                 'EMPTY:0000340',           'droplet'
    'exploit: minimum probability of exploitation', 'EMPTY:0000341',      'exploit: minimum probability of exploitation'
    'sample: minimum probability of sensing',  'EMPTY:0000342',           'sample: minimum probability of sensing'
    'search off patch: probability of sensing below', 'EMPTY:0000343',    'search off patch: probability of sensing below'
    'search off patch: maximum distance into the patch', 'EMPTY:0000344', 'search off patch: maximum distance into the patch'
    'diluent',                                 'NCIT:C60823',             'Diluent'
    };
m = containers.Map(pairs(:, 1), num2cell(pairs(:, 2:3), 2));
end
