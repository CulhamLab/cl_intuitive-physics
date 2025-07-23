%%
fol_data = ".\Data\";
fol_prt = ".\PRTs\";
conditions = ["Baseline" "Hand" "Tool" "Object" "Phase"];

%%
if ~exist(fol_prt, "dir")
    mkdir(fol_prt)
end

%%
list = dir(fol_data + "*.mat");
keep = ~contains({list.name}, "error");
list = list(keep);
number_files = length(list);

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

    % incomplete?
    file = load([list(fid).folder filesep list(fid).name]);
    if isnan(file.d.volData(end).time_startActual)
        fprintf("\tIncomplete run. Skipping...\n");
        continue
    end

    % initialize PRT
    prt = xff('prt');
    prt.Experiment = '4_MovingToolAndHandLocalizer';

    % populate PRT
    c=0;
    for cond_ID = [3 2 4 5]
        % which volumes had presentation of this condition
        is_cond = (file.d.sched(:,2)==4) & (file.d.sched(:,3)==cond_ID);

        % find block on/offset
        d = [0; diff(is_cond)];
        vol_on = find(d==1);    % first vol with presentation
        vol_off = find(d==-1);  % first vol without presentation
        onoff = ([vol_on vol_off]-1) * file.p.TR * 1000;

        % colours
        switch conditions(cond_ID)
            case "Tool"
                colour = [255 0 0];
            case "Hand"
                colour = [0 255 0];
            case "Object"
                colour = [0 0 255];
            case "Phase"
                colour = [128 128 128];
            otherwise
                error
        end

        % Populate PRT
        c=c+1;
        prt.Cond(c).ConditionName = {conditions(cond_ID).char};
        prt.Cond(c).NrOfOnOffsets = size(onoff, 1);
        prt.Cond(c).OnOffsets = onoff;
        prt.Cond(c).Weights = zeros(prt.Cond(c).NrOfOnOffsets, 0);
        prt.Cond(c).Color = colour;
    end

    % save
    prt.SaveAs(fp.char);
end

disp Done.