number_participants = 2;
number_runs = 2;

% Rules:
%   1. There are 36 trials per run organized into 12 triplets of the 3 actions
%   2. Each half of a run contains all 6 unique triplets
%   3. Each action must follow itself 3 or 4 times (one 3 and two 4s)
%   4. Each action must follow each other action exactly 4 times
%   5. 1 trial in each triplet has a longer ITI
%   6. The very last trial never has the long ITI
%   7. Each half of the run has the long ITI in each of the 3 triplet trial positions exactly twice
%   8. Each action is proceeded by the long ITI 4 times
%   9. Each action is followed by the long ITI 4 times

%%
dir_orders = ".\Orders\";

%% names
actions = ["Grasp" "Touch" "Look"];
number_actions = 3; % script is written for a value of 3

%% make the 6 triplets
triplets = perms(1:number_actions);
number_triplets = size(triplets, 1);

%% make output folder
if ~exist(dir_orders, "dir")
    mkdir(dir_orders)
end

%% fixed RNG seed in case we need to recreate anything
rng(1)

%% make each run
for par = 1:number_participants
    for run = 1:number_runs
        % output already exsts?
        fp = dir_orders + sprintf("PAR%02d_RUN%02d.csv", par, run);
        if exist(fp, "file")
            error("Order file already exists: %s", fp)
        end

        % find valid action order
        while 1
            % randomly generate an order made up of two sets of the
            % triplets randomly ordered (all 6 triplets in each half = 12
            % total)
            order = triplets([randperm(number_triplets, number_triplets) randperm(number_triplets, number_triplets)], :);

            % convert from triplets to 1x36 trials
            order_action = permute(order,[2 1]);
            order_action = order_action(:)';

            % first action determined by participant and run numbers
            first_action = mod(((par-1)*number_runs)+run-1, number_actions)+1;
            if order_action(1) ~= first_action
                continue
            end

            % count how many times each action follows each other
            follows = zeros(number_actions, number_actions);
            for trial = 2:length(order_action)
                prior = order_action(trial-1);
                this = order_action(trial);
                follows(prior,this) = follows(prior,this) + 1;
            end

            % stop if balanced enough
            count4 = nnz(follows(:)==4);
            count3 = nnz(follows(:)==3);
            if (count4==8) && (count3==1)
                break
            end
        end

        % find valid assignment of long ITIs
        while 1
            % in each half, 2 long ITI in each of the 3 trial positions
            has_long_ITI = triplets([randperm(number_triplets, number_triplets) randperm(number_triplets, number_triplets)], :) == 3;

            % convert from triplets to 1x36 trials
            order_long_ITI = permute(has_long_ITI,[2 1]);
            order_long_ITI = order_long_ITI(:)';

            % very last trial must not have the long ITI
            if order_long_ITI(end)
                continue
            end

            % defaulting to valid...
            valid = true;

            % each action must be proceeded by the long ITI exactly 4 times
            for action = 1:number_actions
                ind = find(order_action(2:end) == action);
                if nnz(order_long_ITI(ind)) ~= 4
                    valid = false;
                end
            end

            % each action must be followed by the long ITI exactly 4 times
            for action = 1:number_actions
                ind = find(order_action == action);
                if nnz(order_long_ITI(ind)) ~= 4
                    valid = false;
                end
            end

            % stop once valid solution found
            if valid
                break
            end
        end

        % populate table
        tbl = table;
        tbl.Condition = actions(order_action)';
        tbl.HasLongITI = order_long_ITI';
        
        % write table
        writetable(tbl, fp)

    end
end

%% Done
disp Done!