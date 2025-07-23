%%
fol_data = ".\Data\";
fol_prt = ".\PRTs\";

%%
if ~exist(fol_prt, "dir")
    mkdir(fol_prt)
end

%%
list = dir(fol_data + "*.para");
number_files = length(list);
if ~number_files
    error("No complete .mat files found in the specified directory.");
end

%%
for fid = 1:number_files
    fprintf("Processing %d of %d: %s\n", fid, number_files, list(fid).name);

    % output already exists?
    [~,name,~] = fileparts(list(fid).name);
    fp = fol_prt + name + ".prt";
    if exist(fp, "file")
        fprintf("\tOutput file already exists. Skipping...\n");
        continue;
    end

    % initialize PRT
    prt = xff('prt');
    prt.Experiment = '2_SpatialWorkingMemory';

    % load
    tbl = readtable([list(fid).folder filesep list(fid).name], TextType="string", FileType="text");

    % incomplete?
    if height(tbl)<52
        fprintf("\tIncomplete run. Skipping...\n");
        continue;
    end

    % labels
    tbl.Properties.VariableNames=["Onset" "ConditionID" "Duration"];

    % add conditions
    c = 0;
    for condition = ["Easy" "Hard"]
        switch condition
            case "Easy"
                ID = 1;
            case "Hard"
                ID = 2;
            otherwise
                error
        end
        rows = tbl.ConditionID==ID;
        for phase = ["Buildup" "Answer"]
            switch phase
                case "Buildup"
                    delay = 0.5;
                    dur =   4;
                case "Answer"
                    delay = 4.5;
                    dur =   1;
                otherwise
                    error
            end

            % get phase onsets
            onsets = tbl.Onset(rows) + delay;
            
            % calculate phase offsets
            offsets = onsets + dur;
            
            % combine and conver to msec
            onoff = [onsets offsets] * 1000;

            % colour
            if condition=="Hard" && phase=="Answer"
                colour = [255 0 0];
            elseif condition=="Hard" && phase=="Buildup"
                colour = [255 126 121];
            elseif condition=="Easy" && phase=="Answer"
                colour = [0 0 255];
            elseif condition=="Easy" && phase=="Buildup"
                colour = [0 150 255];
            else
                error
            end
            
            % Populate PRT
            c=c+1;
            prt.Cond(c).ConditionName = {[condition.char '_' phase.char]};
            prt.Cond(c).NrOfOnOffsets = size(onoff, 1);
            prt.Cond(c).OnOffsets = onoff;
            prt.Cond(c).Weights = zeros(prt.Cond(c).NrOfOnOffsets, 0);
            prt.Cond(c).Color = colour;
        end
    end

    % save
    prt.SaveAs(fp.char);
end

disp Done.