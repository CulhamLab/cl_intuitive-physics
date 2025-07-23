tbl = readtable("schedule_1.txt", TextType="string");
tbl.Properties.VariableNames = ["Onset" "Condition" "x" "y" "Filename"];

categories = ["Tools" "UpperLimbs" "Objects" "Scrambled"];

prt = xff('prt');
prt.Experiment = '3_StaticToolAndHandLocalizer';

dur = 21;

for c = 1:4
    % Colour
    switch categories(c)
        case "Tools"
            colour = [255 0 0];
        case "UpperLimbs" 
            colour = [0 255 0];
        case "Objects" 
            colour = [0 0 255];
        case "Scrambled"
            colour = [150 150 150];
        otherwise
            error
    end

    % get trial onsets
    rows = tbl.Condition==c;
    trial_onsets = tbl.Onset(rows);

    % find starts of blocks
    block_starts = [0; diff(trial_onsets)]~=1;
    if any(diff(find(block_starts)) ~= dur)
        error
    end
    
    % block onsets
    block_onsets = trial_onsets(block_starts);
    
    % make on/offsets in msec
    onoff = ([block_onsets block_onsets] + [0 dur]) * 1000;

    % Populate PRT
    prt.Cond(c).ConditionName = {categories(c).char};
    prt.Cond(c).NrOfOnOffsets = size(onoff, 1);
    prt.Cond(c).OnOffsets = onoff;
    prt.Cond(c).Weights = zeros(prt.Cond(c).NrOfOnOffsets, 0);
    prt.Cond(c).Color = colour;
end

% save
prt.SaveAs('3_StaticToolAndHandLocalizer.prt');