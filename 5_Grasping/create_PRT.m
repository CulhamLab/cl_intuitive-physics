%%
fol_data = ".\Data\";
fol_prt = ".\PRTs\";

%%
if ~exist(fol_prt, "dir")
    mkdir(fol_prt)
end

%%
list = dir(fol_data + "*.mat");
keep = ~contains({list.name}, ["ERROR" "INCOMPLETE"]);
% keep = ~contains({list.name}, "ERROR");
list = list(keep);
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
    prt.Experiment = '5_Grasping';

    % load
    file = load([list(fid).folder filesep list(fid).name]);

    % populate PRT
    c=0;
    for cond = ["Look" "Touch" "Grasp"]
        % find volumes
        is_cond = (file.d.schedule.Phase=="Execution") & (file.d.schedule.Condition==cond);

        % find block on/offset
        d = [0; diff(is_cond)];
        vol_on = find(d==1);    % first vol with presentation
        vol_off = find(d==-1);  % first vol without presentation

        % onoff in msec
        onoff = file.d.schedule.ExpectedOnset([vol_on vol_off]) * 1000;
        
        % colour
        switch cond
            case "Look" 
                colour = [0 0 255];
            case "Touch" 
                colour = [128 0 0];
            case "Grasp"
                colour = [255 0 0];
            otherwise
                error
        end

        % Populate PRT
        c=c+1;
        prt.Cond(c).ConditionName = {cond.char};
        prt.Cond(c).NrOfOnOffsets = size(onoff, 1);
        prt.Cond(c).OnOffsets = onoff;
        prt.Cond(c).Weights = zeros(prt.Cond(c).NrOfOnOffsets, 0);
        prt.Cond(c).Color = colour;
    end

    % save
    prt.SaveAs(fp.char);
end

disp Done.