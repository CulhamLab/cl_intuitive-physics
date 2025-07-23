%%
fol_data = ".\results\";
fol_prt = ".\PRTs\";

%%
if ~exist(fol_prt, "dir")
    mkdir(fol_prt)
end

%%
list = dir(fol_data + "*_blockorder*.txt");
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
    prt.Experiment = '1_IntuitivePhysics';

    % load
    tbl = readtable([list(fid).folder filesep list(fid).name], TextType="string");

    % incomplete?
    if height(tbl)<42
        fprintf("\tIncomplete run. Skipping...\n");
        continue;
    end

    % labels
    tbl.Properties.VariableNames=["Onset" "ConditionID" "Duration" "Event" "Condition" "Movie" "Response"];
    
    % add conditions
    c = 0;
    for condition = ["Physics" "Colour"]
        switch condition
            case "Physics"
                search_name = "physics";
            case "Colour"
                search_name = "color";
            otherwise
                error
        end
        rows = tbl.Condition==search_name;

        for phase = ["Video" "Answer"]
            switch phase
                case "Video"
                    delay = 1;
                    dur =   6;
                case "Answer"
                    delay = 7;
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
            if condition=="Physics" && phase=="Video"
                colour = [255 0 0];
            elseif condition=="Physics" && phase=="Answer"
                colour = [255 126 121];
            elseif condition=="Colour" && phase=="Video"
                colour = [0 0 255];
            elseif condition=="Colour" && phase=="Answer"
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