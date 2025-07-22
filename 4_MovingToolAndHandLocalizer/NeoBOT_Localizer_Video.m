%NeoBOT_Localizer_Video(subject_number)
%
%Video Localizer for NeoBOT Experiment
%
%Use:
%Call NeoBOT_Localizer_Video with one argument indicating the subject
%number (order number). For example, enter "NeoBOT_Localizer_Video(1)" to
%run the localizer for the first subject/order.
%
%Events:
%1. Read order file (xls)
%2. Check that Psychtoolbox Screen works (assertOpenGL)
%3. Read in each video, adding fixation and flashes as needed (requires
%   several seconds or even minutes)
%4. Wait for first trigger (a single beep will play when recieved)
%5. Run localizer, resyncing with any subsequent triggers
%6. Save timing and button press data
%
%Troubleshooting:
%-If the Psychtoolbox screen is unable to open, enter "close all" and then
% "clear all" in the Command Window, and then try again.
%-On some systems, you may need to change "p.SCREEN_NUMBER" from 1 to 0 in
% order to open the Psychtoolbox Screen.
%-If the issue is not resolved, uncomment
% "Screen('Preference', 'SkipSyncTests', 1)" where indicated at the top of
% the script. Unfortunately, the quality of the playback and timing will be
% impacted if this setting is used so it is recommended for demo purposes
% only.
%
%Keys:
%-Press and hold ESCAPE to stop the script and close the Screen
%-Triggers are recieved as either "t" or "5" key presses
%-Pedal/Button Box is any of 1-4, rgby, and numpad 1-4
%**Keys can be changed under the "keys" heading of the parameters section 
%
function NeoBOT_Localizer_Video(subject_number)

%% Uncomment this only if Matlab fails to open the Psychtoolbox Screen (playback timing will be affected)
% Screen('Preference', 'SkipSyncTests', 1)

%% Check number of inputs
if nargin<1
    help(mfilename)
    error('Not enough inputs.')
end

%% Parameters (all parameters will be placed inside the "p" structure)

%TR in seconds
p.TR = 1;

%durations in seconds (each must be divisible by the TR)
p.DURATION_BASELINE_INITIAL_SEC = 21;
p.DURATION_BASELINE_INTERNAL_SEC = 21;
p.DURATION_BASELINE_FINAL_SEC = 21;
p.DURATION_EACH_PRESENTATION_SEC = 7;

%paths
p.PATH_ORDERS_FOLDER = [pwd filesep 'Orders' filesep];
p.PATH_VIDEOS_FOLDER = [pwd filesep 'Videos' filesep];
p.PATH_SAVE_FOLDER = [pwd filesep 'Data' filesep];
p.PATH_FIXATION = [pwd filesep 'fixation_transparent.png'];

%filetypes
p.FILETYPE_VIDEOS = '.mp4';

%place subject# in params
p.SUBJECT = subject_number;

%filenames
p.FILENAME_ORDER = sprintf('SUB%02d_VID.xls',p.SUBJECT);
p.FILENAME_OUTPUT = sprintf('SUB%02d_TIMESTAMP',p.SUBJECT);

%trigger checking
p.TIME_BEFORE_TRIGGER_START_LOOKING_SEC = 0.005; %should be less than TR
p.TIME_AFTER_MISSED_TRIGGER_STOP_LOOKING_SEC = 0.005;

%keys
KbName('UnifyKeyNames');
p.KEY_TRIGGER = KbName({'5%' 't'}); %5 and/or T
p.KEY_STOP = KbName('escape'); %ESC key
p.KEY_PEDAL = KbName({'1!' '2@' '3#' '4$' 'r' 'g' 'b' 'y' '1' '2' '3' '4'}); %numpad 1-4 + rgby + 1-4

%fixation
p.FIXATION_SHOW = true;
p.FIXATION_SIZE_PIXELS = [50 50]; %height width
p.FIXATION_DURING_BASELINES = true;

%Psychtoolbox screen
p.SCREEN_NUMBER = 2;
p.SCREEN_RECT = []; %[] is fullscreen
p.SCREEN_BGD_COLOUR = [0 0 0]; %black background
p.SCREEN_EXPECTED_FLIP_DELAY_SEC = 1/60; %monitor refresh rate
p.SCREEN_HIDE_MOUSE = true;

%videos/pictures
p.PRESENTATION_RESIZE_PIXELS = [480 854];; %nan  or [height width]
p.TRANSPARENCY_CUTOFF = 240; %lower values remove less at transparency borders (0-255)

%attention task
p.BRIGHTNESS_MULTIPLIER = 1.075; %was 1.05 for SUB 1-3
p.FLASH_DURATION_SEC = 0.040; %ONLY FOR PICTURES
p.TARGET_REACTION_TIME_SEC = 0.750;

%% Check Parameters (not a complete check)

%each duration must be divisible by TR
if mod(p.DURATION_BASELINE_INITIAL_SEC,p.TR) || mod(p.DURATION_BASELINE_FINAL_SEC,p.TR) || mod(p.DURATION_EACH_PRESENTATION_SEC,p.TR)
    error('Durations must be divisible by TR.')
end

%add filesep to paths if needed
if p.PATH_ORDERS_FOLDER(end)~=filesep, p.PATH_ORDERS_FOLDER=[p.PATH_ORDERS_FOLDER filesep];, end
if p.PATH_VIDEOS_FOLDER(end)~=filesep, p.PATH_VIDEOS_FOLDER=[p.PATH_VIDEOS_FOLDER filesep];, end
if p.PATH_SAVE_FOLDER(end)~=filesep, p.PATH_SAVE_FOLDER=[p.PATH_SAVE_FOLDER filesep];, end

%check if order exists
fpOrder = [p.PATH_ORDERS_FOLDER p.FILENAME_ORDER];
if ~exist(fpOrder)
    error('Cannot locate order file.')
end

%create save folder if needed
if ~exist(p.PATH_SAVE_FOLDER)
    mkdir(p.PATH_SAVE_FOLDER)
end

%create timestamp for saved files
c = round(clock);
timestamp = sprintf('%d-%d-%d_%d-%d_%d',c([4 5 6 3 2 1]));
p.FILENAME_OUTPUT = strrep(p.FILENAME_OUTPUT,'TIMESTAMP',timestamp);

%% Load and Process Order File
fprintf('Reading order from Excel file...\n')

%load
[~,~,xls] = xlsread(fpOrder);

%remove any extra rows
while isempty(xls{end,1})
    xls = xls(1:end-1,:);
end

%remove header
d.orderHeaders = xls(1,:);
xls = xls(2:end,:);

%number of trials
d.numTrial = size(xls,1);

%put in data struct (data and param struct are saved)
d.order = xls;

%number of states
d.numStates = size(d.order,1);

%% Check if Psychtoolbox is properly installed:
fprintf('Checking Psychtoolbox functionality...\n')
AssertOpenGL;

%% Load and Prepare Video/Picture + Fixation
fprintf('Loading videos for each state...\n')

%prepare fixation
if p.FIXATION_SHOW & subject_number > 0
    [pres.imgFix,~,transparency] = imread(p.PATH_FIXATION);
    pres.imgFix = imresize(pres.imgFix,p.FIXATION_SIZE_PIXELS);
    transparency = imresize(transparency,p.FIXATION_SIZE_PIXELS)<p.TRANSPARENCY_CUTOFF;
    [yFixUse,xFixUse] = ind2sub(p.FIXATION_SIZE_PIXELS,find(~transparency));
    yxFixInFrame = round([yFixUse,xFixUse] + repmat((p.PRESENTATION_RESIZE_PIXELS/2),[length(yFixUse) 1]) - repmat((p.FIXATION_SIZE_PIXELS/2),[length(yFixUse) 1]));
    pres.indFix = sub2ind(p.FIXATION_SIZE_PIXELS,yFixUse,xFixUse);
    pres.indFix = [pres.indFix; (pres.indFix+prod(p.FIXATION_SIZE_PIXELS)); (pres.indFix+(2*prod(p.FIXATION_SIZE_PIXELS)))]; 
    pres.indFixFrame = sub2ind(p.PRESENTATION_RESIZE_PIXELS,yxFixInFrame(:,1),yxFixInFrame(:,2));
    pres.indFixFrame = [pres.indFixFrame; (pres.indFixFrame+prod(p.PRESENTATION_RESIZE_PIXELS)); (pres.indFixFrame+(2*prod(p.PRESENTATION_RESIZE_PIXELS)))]; 
    %%%to add fixation: IMAGE(pres.indFixFrame) = pres.imgFix(pres.indFix); %<0.002sec
end

%create baseline frame
if subject_number > 0
    pres.imgBaseline = uint8(zeros([p.PRESENTATION_RESIZE_PIXELS 3]));
    if p.FIXATION_SHOW
        pres.imgBaseline(pres.indFixFrame) = pres.imgFix(pres.indFix);
    end
else
    pres.imgBaseline = imread('old_baseline.png');
end

%load in VIDEOs
for state = 1:d.numStates
    fprintf('%d/%d: ',state,d.numStates)
    if strcmp(d.order{state,2},'presentation')
        %get filepath
        cond = d.order{state,3};
        fp = [p.PATH_VIDEOS_FOLDER cond filesep d.order{state,4} p.FILETYPE_VIDEOS];
        fprintf('%s\n',fp)

        %read movie and setup state information
        reader = VideoReader(fp);
        presentation(state).frames = reader.read;
        d.stateData(state).numFrames = get(reader, 'NumberOfFrames');
        d.stateData(state).frameRateFile = get(reader, 'FrameRate');
        d.stateData(state).filepath = fp;
        d.stateData(state).frameTimeTarget = 0 : (p.DURATION_EACH_PRESENTATION_SEC/d.stateData(state).numFrames) : (p.DURATION_EACH_PRESENTATION_SEC - (p.DURATION_EACH_PRESENTATION_SEC/d.stateData(state).numFrames));
        d.stateData(state).frameTimeActual = nan(1,d.stateData(state).numFrames);
        d.stateData(state).frameTimeActualState = nan(1,d.stateData(state).numFrames);
        d.stateData(state).frameRateTarget = d.stateData(state).numFrames / p.DURATION_EACH_PRESENTATION_SEC;
        d.stateData(state).currentFrame = 0;
        d.stateData(state).readyToFlip = false;
        d.stateData(state).time_start = nan;
        d.stateData(state).isPresentation = true;
        d.stateData(state).pedalTimes = [];
        d.stateData(state).pedalTimesState = [];

        %apply brightness
        d.stateData(state).flashFrames = d.order{state,5};
        for frame = d.stateData(state).flashFrames
            if isnan(frame), continue, end
            presentation(state).frames(:,:,:,frame) = presentation(state).frames(:,:,:,frame) * p.BRIGHTNESS_MULTIPLIER;
        end

        %add fixation
        if p.FIXATION_SHOW & subject_number > 0
            indFixAll = [];
            indFixFrameAll = [];
            addInd = prod([p.PRESENTATION_RESIZE_PIXELS 3]);
            for frame = 1:d.stateData(state).numFrames
                indFixAll = [indFixAll; pres.indFix];
                indFixFrameAll = [indFixFrameAll; pres.indFixFrame + ((frame-1)*addInd)];
            end
            presentation(state).frames(indFixFrameAll) = pres.imgFix(indFixAll);
        end
    else
        fprintf('no presentation\n')
        d.stateData(state).isPresentation = false;
    end
end

memory

%% Create Volume Schedule

%ROW = Volume
%
%COLUMN 1: State Number
%COLUMN 2: Action (1=baseline_initial, 2=baseline_internal, 3=baseline_final, 4=presentation)
%COLUMN 3: Condition (1=baseline, 2=Hand, 3=Tool, 4=Object, 5=Phase)

actionNames = {'baseline_initial' 'baseline_internal' 'baseline_final' 'presentation'};
condNames = {'baseline' 'Hand' 'Tool' 'Object' 'Phase'};

d.sched = [];

for state = 1:d.numStates
    actionName = d.order{state,2};
    actionNum = find(strcmp(actionNames,actionName));
    
    condName = d.order{state,3};
    condNum = find(strcmp(condNames,condName));
    
    %duration
    switch actionName
        case 'baseline_initial' 
            dur = p.DURATION_BASELINE_INITIAL_SEC / p.TR;
        case 'baseline_internal' 
            dur = p.DURATION_BASELINE_INTERNAL_SEC / p.TR;
        case 'baseline_final' 
            dur = p.DURATION_BASELINE_FINAL_SEC / p.TR;
        case 'presentation'
            dur = p.DURATION_EACH_PRESENTATION_SEC / p.TR;
        otherwise
            error('Unknown Action')
    end
    
    for v = 1:dur
        d.sched(end+1,:) = [state actionNum condNum];
    end
    
end
d.numVol = size(d.sched,1);

%% Try...
try

%% Prepare Screen
s.win = Screen('OpenWindow',p.SCREEN_NUMBER,p.SCREEN_BGD_COLOUR,p.SCREEN_RECT);

%% Wait First Trigger

%spacing
fprintf('\n\n\n\n\n\n\n')

%initialize
d.volData = repmat(struct('time_startActual',nan,'time_start',nan,'time_endActual',nan,'volDuration',nan,'volDurationActual',nan,'recievedTrigger',false),[1 d.numVol]);
numFlashes = length([d.stateData.flashFrames]);
d.attentionData = repmat(struct('time_flash',nan,'time_pedal',nan,'RT',nan),[1 numFlashes]);
d.counterAttention = 0;
state = 0;
pedalOpen = true;
d.allPedalTimes = [];

%improve later response times
GetSecs;
KbCheck;

%make a beep to play when triger is recieved
[beepSnd,beepFreq] = MakeBeep(500,0.25);

%make sure nothing is pressed currently
fprintf('Waiting for all keys to release...\n')
while KbCheck, end

%draw baseline frame now
Screen('PutImage', s.win, pres.imgBaseline); %~.007sec
Screen('DrawingFinished',s.win); %~.0001sec
Screen('Flip',s.win); %~.01sec
if p.SCREEN_HIDE_MOUSE
    HideCursor
end

%ready message
fprintf('Starting experiment with %d volumes (%d sec).\n----------------------------------------------------------------------\nWaiting for first trigger...\n----------------------------------------------------------------------\n',d.numVol,d.numVol*p.TR);

%wait for first trigger
while 1
    %%%%KbWait; %more efficient way to wait for a key
    [keyIsDown, secs, keyCode] = KbCheck(-1); %get key(s)
    if any(keyCode(p.KEY_TRIGGER))
        break
    elseif any(keyCode(p.KEY_STOP))
        error('Stop key was pressed.')
    end
end

%get time zero first
t0 = GetSecs;

%beep
sound(beepSnd,beepFreq)

%% Do Experiment
for v = 1:d.numVol
    %volume start time
    if v==1
        d.volData(v).time_startActual = 0;
    else
        d.volData(v).time_startActual = GetSecs-t0;
    end
    if v==1 | d.volData(v-1).recievedTrigger %is first vol OR prior vol recieved trigger
        d.volData(v).time_start = d.volData(v).time_startActual; %use actual time
    else %missed a trigger
        d.volData(v).time_start = d.volData(v-1).time_start + p.TR; %use expected trigger time
    end
    
    %state
    stateVol = d.sched(v,1);
    
    %new state?
    if state~=stateVol
        state = stateVol;
        t0_state = d.volData(v).time_start + t0;
        d.stateData(state).time_start = d.volData(v).time_start;
    end
    
    %events
    action = actionNames{d.sched(v,2)};
    actionNum = d.sched(v,2);
    cond = condNames{d.sched(v,3)};
    fprintf('\nStarting volume %d/%d at %fsec (actual %fsec):\nState: %d\nAction: %s\nCondition: %s\n',v,d.numVol,d.volData(v).time_start,d.volData(v).time_startActual,state,action,cond);
    
    %place info in volData
    d.volData(v).state = state;
    d.volData(v).action = action;
    d.volData(v).actionNum = actionNum;
    d.volData(v).cond = cond;
    
    %start of event
    if actionNum==4 %presentation
        fprintf('Presentation: %s\n',d.order{state,4});
        nextFrame = d.stateData(state).currentFrame + 1;
    else %baseline
        Screen('PutImage', s.win, pres.imgBaseline);
        Screen('DrawingFinished',s.win);
        Screen('Flip',s.win);
        
        %if the next volume is presentation, prepare its first frame
        if v<d.numVol & d.sched(v,1)~=d.sched(v+1,1) & d.sched(v+1,2)==4 & ~d.stateData(state+1).readyToFlip
            Screen('PutImage', s.win, presentation(state+1).frames(:,:,:,1)); 
            Screen('DrawingFinished',s.win);
            d.stateData(state+1).readyToFlip = true;
        end
    end
    
    %wait until it is time to check for trigger + look for pedal
    saved = false;
    while 1
        timeInVol = (GetSecs-t0) - d.volData(v).time_start;
        if (p.TR-timeInVol)<=p.TIME_BEFORE_TRIGGER_START_LOOKING_SEC
            break
        end
            
        if actionNum<4 & ~saved %not during presentation
            %if there is time to spare before looking for trigger, save data
            save([p.PATH_SAVE_FOLDER p.FILENAME_OUTPUT],'p','d')
            saved=true;
        end
        
        %check pedal
        [keyIsDown, secs, keyCode] = KbCheck(-1);
        if sum(keyCode(p.KEY_PEDAL)) & pedalOpen
           
            % pedal pressed!
            fprintf('-pedal pressed!\n')
            t = GetSecs;
            d.stateData(state).pedalTimes(end+1) = t-t0;
            d.stateData(state).pedalTimesState(end+1) = t-t0_state;
            d.allPedalTimes(end+1) = t-t0;
            pedalOpen = false;
            if d.counterAttention & isnan(d.attentionData(d.counterAttention).time_pedal)
                d.attentionData(d.counterAttention).time_pedal = t-t0;
                d.attentionData(d.counterAttention).RT = d.attentionData(d.counterAttention).time_pedal - d.attentionData(d.counterAttention).time_flash;
            end
            
        elseif any(keyCode(p.KEY_STOP))
            error('Stop key was pressed.')   
        elseif ~sum(keyCode(p.KEY_PEDAL)) & ~pedalOpen
            pedalOpen = true;
        end 
        
        %play presentation
        if actionNum==4
            if nextFrame<=d.stateData(state).numFrames
                timeInState = (GetSecs-t0_state);
                
                if ~d.stateData(state).readyToFlip
                    Screen('PutImage', s.win, presentation(state).frames(:,:,:,nextFrame)); 
                    Screen('DrawingFinished',s.win);
                    d.stateData(state).readyToFlip = true;
                end
                
                if (d.stateData(state).frameTimeTarget(nextFrame) - p.SCREEN_EXPECTED_FLIP_DELAY_SEC)<=timeInState %time for next flip!
                    %next frame!
                    timeThisFrame = Screen('Flip',s.win);
                    d.stateData(state).readyToFlip = false;
                    d.stateData(state).currentFrame = nextFrame;
                    d.stateData(state).frameTimeActual(nextFrame) = (timeThisFrame-t0);
                    d.stateData(state).frameTimeActualState(nextFrame) = (timeThisFrame-t0_state);
                    if any(d.stateData(state).flashFrames==nextFrame)
                        fprintf('-Flash!\n')
                        d.counterAttention = d.counterAttention + 1;
                        if d.counterAttention > numFlashes
                            d.attentionData(d.counterAttention) = struct('time_flash',nan,'time_pedal',nan,'RT',nan); %just in case
                        end
                        d.attentionData(d.counterAttention).time_flash = timeThisFrame-t0;
                    end
                    nextFrame = nextFrame + 1;
                end
            elseif v<d.numVol & d.sched(v,1)~=d.sched(v+1,1) & d.sched(v+1,2)==4 & ~d.stateData(state+1).readyToFlip %done presentation, load next frame
                Screen('PutImage', s.win, presentation(state+1).frames(:,:,:,1)); 
                Screen('DrawingFinished',s.win);
                d.stateData(state+1).readyToFlip = true;
            end
            
        end
        
    end
    
    %look for trigger until time runs out + look for pedal
    
    d.volData(v).recievedTrigger = false; %default
    while 1
        timeInVol = (GetSecs-t0) - d.volData(v).time_start;
        
        [keyIsDown, secs, keyCode] = KbCheck(-1); %get key(s)
        if any(keyCode(p.KEY_TRIGGER))
            d.volData(v).recievedTrigger = true;
            fprintf('~~~~~~~~~~~~~~~~~TRIGGER RECIEVED~~~~~~~~~~~~~~~~~\n')
            break
            
        elseif sum(keyCode(p.KEY_PEDAL)) & pedalOpen
           
            % pedal pressed!
            fprintf('-pedal pressed!\n')
            t = GetSecs;
            d.stateData(state).pedalTimes(end+1) = t-t0;
            d.stateData(state).pedalTimesState(end+1) = t-t0_state;
            d.allPedalTimes(end+1) = t-t0;
            pedalOpen = false;
            if d.counterAttention & isnan(d.attentionData(d.counterAttention).time_pedal)
                d.attentionData(d.counterAttention).time_pedal = t-t0;
                d.attentionData(d.counterAttention).RT = d.attentionData(d.counterAttention).time_pedal - d.attentionData(d.counterAttention).time_flash;
            end
            
        elseif any(keyCode(p.KEY_STOP))
            error('Stop key was pressed.')   
        elseif ~sum(keyCode(p.KEY_PEDAL)) & ~pedalOpen
            pedalOpen = true;
        end 
        
        
        if timeInVol>(p.TR+p.TIME_AFTER_MISSED_TRIGGER_STOP_LOOKING_SEC)
            warning('No trigger was recieved. Continuing with expected timing...')
            break
        end
    end
    
    %end of volume timing
    d.volData(v).time_endActual = GetSecs-t0;
    d.volData(v).volDuration = d.volData(v).time_endActual - d.volData(v).time_start;
    d.volData(v).volDurationActual = d.volData(v).time_endActual - d.volData(v).time_startActual;
    fprintf('-duration: %f seconds\n',d.volData(v).volDuration)
    
end

%% Done
ShowCursor;
sca
sca%sometimes it can take 2 attempts to close a screen
save([p.PATH_SAVE_FOLDER p.FILENAME_OUTPUT],'p','d')
reportAttention(p,d)
disp Done.

%% ...Catch
catch err
    ShowCursor;
    sca
    sca%sometimes it can take 2 attempts to close a screen
    clear presentation
    save([p.PATH_SAVE_FOLDER p.FILENAME_OUTPUT '_error'])
    reportAttention(p,d)
    rethrow(err)
end

function reportAttention(p,d)
if ~any(strcmp(fields(d),'attentionData')), return, end
RTs = [d.attentionData(1:d.counterAttention).RT];
numCorrect = sum(RTs<=p.TARGET_REACTION_TIME_SEC);
numMissed = sum(isnan(RTs));
numLate = sum(RTs>p.TARGET_REACTION_TIME_SEC);
fprintf('Reaction Times:\n')
disp(RTs)
fprintf('Attention Task:\n');
fprintf('-Accuracy: %g%%\n',numCorrect/d.counterAttention*100);
fprintf('-Correct: %d/%d\n',numCorrect,d.counterAttention);
fprintf('-Missed: %d/%d\n',numMissed,d.counterAttention);
fprintf('-Late: %d/%d\n',numLate,d.counterAttention);
