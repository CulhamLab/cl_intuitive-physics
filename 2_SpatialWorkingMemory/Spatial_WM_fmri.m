function [] = Spatial_WM_fmri(subj_ID,run_num)

KbName('UnifyKeyNames');
keysToCheck = KbName({'1!', '2@', '3#', '4$', 'R', 'G', 'B', 'Y', 'r', 'g', 'b', 'y'});

clock_time = clock;
rng('default')
rng('shuffle');
% rand('seed',clock_time(end));
rootDir=pwd()
save_path = [rootDir filesep 'Data/'];

esckey = KbName('ESCAPE');

%%% trial list %%%
% 1 = easy
% 2 = hard
% 3 = fixation

%%% correct answers %%%
% -1 = correct on left
%  1 = correct on right
%  0 = no answer (fixation trial)

%%% input keys %%%
% 49 = 1 
% 50 = 2
% 51 = 3
% 52 = 4
% 82 = R
% 72 = G
% 66 = B
% 89 = Y

switch run_num
    case 1
    trial_list = [3 1 1 1 1 2 2 2 2 2 2 2 2 1 1 1 1 3 2 2 2 2 1 1 1 1 1 1 1 1 2 2 2 2 3 1 1 1 1 2 2 2 2 2 2 2 2 1 1 1 1 3];
    case 2
    trial_list = [3 2 2 2 2 1 1 1 1 1 1 1 1 2 2 2 2 3 1 1 1 1 2 2 2 2 2 2 2 2 1 1 1 1 3 2 2 2 2 1 1 1 1 1 1 1 1 2 2 2 2 3];
    otherwise
    error('input variable run_num must have a value of either 1 for fixEasyHard trial presentations, or 2 for fixHardEasy')
end

% -1 = correct on left, 1 = correct on right
correct_side = [0 Shuffle([ones(1,8) -ones(1,8)]) 0 Shuffle([ones(1,8) -ones(1,8)]) 0 Shuffle([ones(1,8) -ones(1,8)]) 0];

trial_duration = [16 8*ones(1,16) 16 8*ones(1,16) 16 8*ones(1,16) 16];
trial_end = cumsum(trial_duration);

%pair list
pairs = [1 1 2 2 3 3 4 5 5 6 6  7 7  8  9  10 11;
         2 5 3 6 4 7 8 6 9 7 10 8 11 12 10 11 12]';
     
pair_list = zeros(4,length(trial_list));
for trial = 1:length(trial_list)
   
    switch trial_list(trial)
        case 1
            grid = randperm(12);
            pair_list([1 3 5 7],trial) = grid(1:4)';
        case 2
            idx = 1;
            while idx < 5
                pair_sample = pairs(randi(length(pairs)),:);
                if ~sum(ismember(pair_list(:,trial),pair_sample(1))) && ~sum(ismember(pair_list(:,trial),pair_sample(2)))
                    pair_list((2*idx)-1:2*idx,trial) = pair_sample;
                    idx = idx+1;
                end
            end
            pair_list(:,trial) = Shuffle(pair_list(:,trial));
        case 3 %fixation, do nothing  
    end
end
     
incorrect_list = zeros(4,length(trial_list));
for trial = 1:length(trial_list)
    switch trial_list(trial)
       case 1
           x = 1;
       case 2
           x = randi(2);
       case 3
           continue  
    end
    trial_pairs = pair_list(:,trial);
    trial_pairs(trial_pairs==0) = [];
    replace_indx = randperm(length(trial_pairs));
    replace_indx = replace_indx(1:x);
    replace_vals = Shuffle(setdiff(1:12,trial_pairs));
    replace_vals = replace_vals(1:x);
    trial_pairs(replace_indx) = replace_vals;
    incorrect_list(1:length(trial_pairs),trial) = trial_pairs;
    
end

%handle duplicate filename, and other checks

if ischar(subj_ID) == 0
    error('subj_ID must be a string')
end

if exist([save_path  subj_ID '.txt'],'file')
    overwrite = input('A file is already saved with this name. Overwrite? (y/n): ','s');
    if overwrite == 'y' %do nothing
    else %anything besides 'y', input new name
        subj_ID = input('Enter a new run identifier: ','s');
    end   
end

save_file = fopen([save_path subj_ID '.txt'],'w');
para_file= fopen([save_path subj_ID '.para'],'w');

%% set up experiment
Screen('Preference', 'SkipSyncTests', 1);
AssertOpenGL;
KbReleaseWait; % Wait until user releases keys on keyboard
screenNumber = max(Screen('Screens'));
Screen('Preference', 'SuppressAllWarnings', 1);
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);
blue = [0 0 255];
[w screenRect]=Screen('OpenWindow',screenNumber, white);

% rects
box_size = round(screenRect(3)/12);
test_distance = round(2.5*box_size);
rect_locations_x = [-1.5 -.5 .5 1.5 -1.5 -.5 .5 1.5 -1.5 -.5 .5 1.5];
rect_locations_y = [-1 -1 -1 -1 0 0 0 0 1 1 1 1];

for rect_num = 1:12
    box_rects(rect_num,:) = CenterRect([0 0 box_size-5 box_size-5], screenRect) + box_size*[rect_locations_x(rect_num) rect_locations_y(rect_num) rect_locations_x(rect_num) rect_locations_y(rect_num)];
end

background_rect = CenterRect([0 0 4*box_size+5 3*box_size+5], screenRect);


%fixation texture
fix_image = white*ones(31,31);fix_image(:,14:18) = 0;fix_image(14:18,:) = 0;
fix_image = uint8(cat(3,fix_image,fix_image,fix_image));
fixation_tex = Screen('MakeTexture', w, fix_image);


%% start experiment
priorityLevel = MaxPriority(w); 
Priority(priorityLevel);

%display run ready message
Screen(w, 'TextSize',50);
Screen(w,'DrawText','Waiting for trigger...',10,10,10);
Screen('DrawTexture', w, fixation_tex); %fixation cross
Screen('Flip', w);

%fixation ready for post-trigger flip
Screen('DrawTexture', w, fixation_tex); %fixation cross

% wait for trigger
while 1
    [~, ~, keyCode] = KbCheck(-3);
    if  keyCode(KbName('=+')) || keyCode(KbName('+')) || keyCode(KbName('t')) || keyCode(KbName('T')) || keyCode(KbName('5'))
        break
    end
end

run_start_time = Screen('Flip', w);

for trial = 1:length(trial_list);
    
    response = 0;
    
    if trial_list(trial) < 3
        
        box_counter = 1;

        %initial fixation time
        WaitSecs(.5);

        %four flashes, 1s each
        for flash_num = 1:4
            drawgrid;
            blue_box(pair_list(box_counter,trial),0);
            blue_box(pair_list(box_counter+1,trial),0);
            Screen('Flip', w);
            box_counter = box_counter + 2;
            WaitSecs(1);
        end

        %choice, 3s
        draw_response_grids;

        %correct arrangement
        for box_num = 1:8
            blue_box(pair_list(box_num,trial),correct_side(trial));        
        end

        %incorrect arrangement
        for box_num = 1:8
            blue_box(incorrect_list(box_num,trial),-correct_side(trial));        
        end    

        response_period_start = Screen('Flip', w);
        
		%{
		%original answer capture before changes on 07-21-2025
		while GetSecs < response_period_start+3
            [~, ~, keyCode] = KbCheck(-1);
            if sum(keyCode(30:35)) %if any number 1-6 is pressed
                response = find(keyCode,1);
            end
        end
		%}

		while GetSecs < response_period_start+3
			[~, ~, keyCode] = KbCheck;
            if any(keyCode(keysToCheck)) && ~(keyCode(KbName('=+')) || keyCode(KbName('+')) || keyCode(KbName('t')) || keyCode(KbName('T')) || keyCode(KbName('5'))) % use the keys for the button for input
                response = find(keyCode,1);
            end
        end
		
        Screen('DrawTexture', w, fixation_tex); %fixation cross
        Screen('Flip', w);
    
    end
    
    %record save file data
    trial_start=trial_end(trial)-trial_duration(trial);
    fprintf(save_file,'%i\t%i\t%i\n',trial_list(trial),correct_side(trial),response); %add trial to save file
    fprintf(para_file,'%i\t%i\t%i\n',trial_start,trial_list(trial),trial_duration(trial)); %add trial to para file
    
    %wait for end of trial
    while GetSecs < run_start_time + trial_end(trial);end
    
    %Abort if escape is pressed
    [~,~,keyCode] = KbCheck(-1);
    if keyCode(esckey)
        break;
    end;
    

end %end all trials


disp('total run time:')
disp(GetSecs - run_start_time)

Priority(0);
Screen('CloseAll');

fclose(save_file);
fclose(para_file);

FlushEvents;




%%%%%%% functions %%%%%%%

function [] = drawgrid()
    Screen('FillRect', w, black, background_rect);
    for rect_number = 1:12
        Screen('FillRect', w, white, box_rects(rect_number,:));
    end
end

function [] = draw_response_grids()
    Screen('FillRect', w, black, background_rect + [test_distance 0 test_distance 0]);
    for rect_number = 1:12
        Screen('FillRect', w, white, box_rects(rect_number,:) + [test_distance 0 test_distance 0]);
    end
    
    Screen('FillRect', w, black, background_rect - [test_distance 0 test_distance 0]);
    for rect_number = 1:12
        Screen('FillRect', w, white, box_rects(rect_number,:) - [test_distance 0 test_distance 0]);
    end
end

function [] = blue_box(box_position,side)
    if box_position > 0
        Screen('FillRect', w, blue, box_rects(box_position,:) + side*[test_distance 0 test_distance 0]);
    end
end



end %end main function     
       
                
