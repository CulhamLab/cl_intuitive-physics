%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function oneback('subject', run)
%   parameters: string subject, integer run
%   preconditions:
%       requires subdirectory 'experiment_stims', to be placed in working directory
%       requires creation of plaintext file indicating the names of the stim
%           files in the stims directory for subject for run.
%           plaintext file should be named [subject]_run[run].txt
%           e.g., 'sub0002_run1'
%           Plaintext file contains 1 line per stim, with 2 tab-delimited columns. The
%           first column indicates the stim number and is an integer. The
%           second column indicates the filename.
%           e.g.,:
%               1   category1/stim1.jpg
%               2   category1/stim2.jpg ...
%               etc....
%               60  category9/stim10.jpg
%
%       requires creation of a .mat schedule file named run[run].mat
%           schedule matrix is a matrix with rows=number of trials in the
%           run and 2 columns. The first column, schedule(:,1), contains
%           the index of the stimlist corresponding to the image to be
%           displayed. The second column, schedule(:,2) contains the
%           cumulative number of seconds following the start of the
%           experiment at which the the stim should be presented --
%           basically, the cumulative onset of the trial.
%           These files are called schedule_1.mat, schedule_2.mat, etc.
%--------------------------------------------------------------------------
% Author: Chris McNorgan
% Date: November 1, 2013
%--------------------------------------------------------------------------
function oneback(subject, runnumber)

%% Change KP/GP on lines: 193/194, 238, 242

%% SOME MISC PARAMETERS -- CHANGE AS YOU SEE FIT
start_fixation_vols=1; %how many triggers at the beginning of the run do we listen for before starting the experiment?
end_fixation_vols=6;%how many volumes at the end of the run (after last fixation trial) do we continue?
TR=2; %what is the TR (acquisition time for 1 volume)?
stim_presentation_time=0.75; %how long (in seconds) is a stim image presented before replaced by fixation?
% screendim=[1280 800]; %assuming the projector has screen dimensions 1920x1080. Stims will be resized to fill screen. Experimental window fills screendim.
screendim=[1920 1080];
imdim=fliplr(screendim); %to my surprise, image dimensions are specified YX insteady of XY
numstims=21; %how many items are there per category?

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Handling key presses and triggers
KbName('UnifyKeyNames');
% identities for 1 & 5 keys: keypad and keyboard (I think)
% These values are predicated on the assumption that the S will have a
% keypad and pushes the number '1' to indicate a stimulus repetition, and
% that the scanner trigger comes in the form of a number '5', also throught
% the keyboard port (this setup is common with Siemens scanners I have
% seen). Change as appropriate if these events come in, e.g., through the
% mouse port

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Stimuli and data recording information
schedule_file=['schedule_' num2str(runnumber) '.txt']; %has the sequence of images and timings
%stimlist_file=[subject '_run' num2str(run) '.txt']; %has the filenames of the images for preloading
%folders has the folder names under stims/ that contain each of the images.
%Note the array index: NULL=1, Headless_bodies=2, etc.
%Note also in the schedule file, NULL=1, Headless_bodies=1, etc.
%So the condition number in the schedule file = index(folder)-1. This will
%be used to dynamically load the images.
folders={'Tools', 'Upper_limbs', 'Objects', 'Scrambled'};
stimsdir='experiment_stims';
%get the names of the stims
f=fopen([pwd filesep schedule_file], 'r'); %open stim file list for reading
scheduledata=textscan(f,'%d\t%d\t%d\t%d\t%s');
fclose(f);
schedule=scheduledata{1}; %first column is the cumulative onset of each event
conditions=scheduledata{2}; %second column is the category of object to display for this event
imgnames=scheduledata{5};%fifth column contains the name of the image to display for this event
imageset=zeros(imdim(1), imdim(2), 3, numstims, length(folders)); %initialize array for screendim x 3 channels x 7 images x 8 folders

isloaded=zeros(numstims,length(folders)); %indicate whether we've already loaded in a particular stim (avoids re-processing NULLs and 1-back repeats)
durations=scheduledata{3};
lastfixationtime=durations(length(durations)); %the duration of the last NULL event is the last duration in the list.
%iterate through each imagename, store named file in buffer
display('Loading stimuli');
%Going to make new copies of the schedules, conditions only for
%experimental trials.
newschedule=nan(length(find(conditions>0)),1);
newconditions=nan(length(find(conditions>0)),1);
imgindices=nan(length(find(conditions>0)),1); %This will store the index into the imageset for the stimulus for a given trial
valididx=1;
for i=1:length(schedule)
    imgfilename=imgnames{i}; %filename is a string, so this will be a cell
    imgidx='';
    compstring='0123456789'; %check each character of filename against this string of digits
    for sl=1:length(imgfilename)
        if ~isempty(strfind(compstring,imgfilename(sl))) %if the character is found in the digit string, it's a digit, so tack it on...
            imgidx=[imgidx imgfilename(sl)];
        end
    end
    imageidx=str2double(imgidx); %Found all the digits in the filename. Convert to a number. This is the image index.
    condition=conditions(i); %conditions is an array. NULL is condition 0. The first real condition is condition 1
    if ( condition>0 ) %if this is not a NULL
        if ~isloaded(imageidx, condition)
            folder=folders{condition}; %look up the folder name for this image
            imgpath=[pwd filesep stimsdir filesep folder filesep imgfilename];
            tmp = imread([imgpath]);
            tmp = imresize(tmp,imdim,'bilinear');
            imageset(:,:,:,imageidx, condition) = tmp; %store the image into the imageset
            isloaded(imageidx, condition)=1;
        end
        newschedule(valididx)=schedule(i);
        newconditions(valididx)=conditions(i);
        imgindices(valididx)=imageidx;
        valididx=valididx+1;
    end
end
schedule=newschedule;
conditions=newconditions;
clear newschedule newconditions;
fiximpath=[pwd filesep stimsdir filesep 'fixation_800x600.bmp'];
fixation_img=imread([fiximpath]);
fixation_img=imresize(fixation_img,imdim,'bilinear');
logfilename=[subject '_run_' num2str(runnumber) '_' datestr(now(), 'dd.mm.yyyy.HH_MM') '.mat'];

%% Works to this point!

%% Logic:
% iterate through schedule to find time onsets of each event
% iterate through conditions, imgindices to find the condition and the
% image number for that event
% use condition + image index to figure out which data in imageset
% corresponds to this trial and display it for a duration of
% stim_presentation_time, after which point, the NULL fixation appears
% until the next scheduled event onset.


timeline={}; %Structure to store all the keypress events
event=struct(); %an event is a structure that stores information about individual keypresses

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Display setup
% Get screenNumber of stimulation display. We choose the display with
% the maximum index, which is usually the right one, e.g., the external
% display on a Laptop:
AssertOpenGL;
screens=Screen('Screens');
screenNumber=min(screens); %% CHANGED to min(screens), which should select your laptop screen. Turn on display mirroring and set your laptop resolution to match that of your projector. Trust me, this is what you want to do.
% Hide the mouse cursor:
HideCursor;

% Returns as default the mean gray value of screen:
gray=GrayIndex(screenNumber);
% Open a double buffered fullscreen window on the stimulation screen
% 'screenNumber' and choose/draw a gray background. 'w' is the handle
% used to direct all drawing commands to that window - the "Name" of
% the window. 'wRect' is a rectangle defining the size of the window.
% See "help PsychRects" for help on such rectangles and useful helper
% functions:
%[w, wRect]=Screen('OpenWindow',screenNumber, gray);
% This will make your window fill your screen to a maximum of screendim
% resolution.
[w, wRect]=Screen('OpenWindow',screenNumber,  gray,[0 0 screendim]);

% Set text size (Most Screen functions must be called after
% opening an onscreen window, as they only take window handles 'w' as
% input:
Screen('TextSize', w, 32);
% Do dummy calls to GetSecs, WaitSecs, KbCheck to make sure
% they are loaded and ready when we need them - without delays
% in the wrong moment:
KbCheck;
WaitSecs(0.1);
GetSecs;

% Set priority for script execution to realtime priority:
priorityLevel=MaxPriority(w);
Priority(priorityLevel);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tex=Screen('MakeTexture', w, fixation_img);
Screen('DrawTexture', w, tex);
[VBLTimestamp startrt]=Screen('Flip', w); %show fixation at start of experiment

%% RunDuration is measured from this point here! (before any dummy volumes)
rstart=tic(); 

%% IMPORTANT: select EITHER KPDummyVolumes OR GPDummyVolumes. 
%  You must select exactly 1 of these. GPDummyVolumes initializes gamepad
%  as a side-effect. Comment out the one you are not using. 
 KPDummyVolumes(start_fixation_vols);
% GPDummyVolumes(start_fixation_vols); %FOR USE WITH GAMEPAD

%This is where the stims really begin
trialctr=1; %indicates what trial of the schedule we are on

nextonset=schedule(trialctr);
nextimage=imgindices(trialctr);
nextcondition=conditions(trialctr);
%stims are indexed by imageset(x,y,rgb, imagenumber, conditionnumber)
nextimagedata=imageset(:,:,:,nextimage,nextcondition);
%pre-draw first stim
% make texture image out of image matrix for next image
tex=Screen('MakeTexture', w, nextimagedata);

% Draw texture image to backbuffer. It will be automatically
% centered in the middle of the display if you don't specify a
% different destination:
Screen('DrawTexture', w, tex);

disp("Starting...");

tstart=tic();
while(trialctr <= length(schedule)) %so long as we have more trials to go...
    elapsed=toc(tstart);
    event=struct(); %a new empty event container is created for every stim
    event.trial=trialctr;
    event.condition=folders{conditions(trialctr)}; %Will record the condition in terms of the folder name which is more easily interpreted.
    event.stim=imgindices(trialctr); %This is the stim number within the folder. (E.g. stim 3 in Tools is Tools3.bmp)
    if (elapsed >= nextonset)
        %% Elapsed time shows it is time to show the next stim...
        % Show stimulus on screen at next possible display refresh cycle,
        % and record stimulus onset time in 'startrt':
        [~, startrt]=Screen('Flip', w);
        elapsed=toc(tstart); %recapture the elapsed time to immediately after the stim has been presented...
        event.timestamp=elapsed; %...and record it.
        Screen('Close', tex); %clear out texture so as not to tax system memory
%         save(logfilename, 'timeline'); %Running save at start of each trial of timeline so far. If this is disruptive, you can comment this out, and logfile will be saved once, at the end of the run.
        
        %get the fixation image ready
        tex=Screen('MakeTexture', w, fixation_img);
        Screen('DrawTexture', w, tex);
        
        % Display stim for stim_presentation_time duration, then flip to
        % fixation
        while ( (GetSecs - startrt) < stim_presentation_time )
            %During that period, poll for subject response
%             event=getGPOneBackResponse(event, startrt, trialctr, conditions, imgindices);
            event=getKPOneBackResponse(event, startrt, trialctr, conditions, imgindices);
        end
        [~, ~]=Screen('Flip', w); %show fixation
        Screen('Close', tex); %clear out fixation texture so as not to tax system memory
%         event=getGPOneBackResponse(event, startrt); %continue polling for response, in case subject has not responded yet
        event=getKPOneBackResponse(event, startrt);
        timeline{length(timeline)+1}=event; %tack previous button events to end of timeline      
        %get next onset and stim image and pre-draw it
        try
            nextonset=schedule(trialctr+1);
            nextimage=imgindices(trialctr+1);
            nextcondition=conditions(trialctr+1);
            %stims are indexed by imageset(x,y,rgb, imagenumber, conditionnumber)
            nextimagedata=imageset(:,:,:,nextimage,nextcondition);
            %pre-draw first stim
            % make texture image out of image matrix for next image
            tex=Screen('MakeTexture', w, nextimagedata);
            Screen('DrawTexture', w, tex);
        catch
            tex=Screen('MakeTexture', w, fixation_img);
            Screen('DrawTexture', w, tex);
        end
        trialctr=trialctr+1;
    end
    %once we get to this point, we are about to move to the next trial
end

%We can wind down now and show fixation for some number of volumes (end_fixation_vols) after
%the last experimental trial to allow signal to drift back to baseline.
Screen('Close', tex);
tex=Screen('MakeTexture', w, fixation_img);
Screen('DrawTexture', w, tex);
[~, ~]=Screen('Flip', w); %show fixation
pause(lastfixationtime); %First, show the fixation for the number of seconds indicated in the schedule file

%Then wait an extra number of TRs before finishing (this is not dependent on
%trigger timing, so it may be off by a few milliseconds from when the
%scanner has finished). The important thing here is that the participant will see
%only fixation between the last stimulus and the end of the run
pause(TR*end_fixation_vols); 
RunDuration=toc(rstart);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Experiment is done
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Screen('CloseAll');
ShowCursor;
fclose('all');
Priority(0);

% Go through timeline, and format into a more spreadsheet-friendly format.
TSTAMPS=[];
TRIALS=[];
CONDITIONS={};
STIMS=[];
ACCS=[];
RTS=[];
for t=1:length(timeline)
    event=timeline{t};
    TSTAMPS(t,1)=event.timestamp;
    TRIALS(t,1)=event.trial;
    CONDITIONS{t,1}=event.condition;
    STIMS{t,1}=event.stim;
    if isfield(event, 'RT')
        RTS(t,1)=event.RT;
    else
        RTS(t,1)=NaN;
    end
    if isfield(event, 'ACC')
        ACCS(t,1)=event.ACC;
    else
        ACCS(t,1)=NaN;
    end
end
save(logfilename, 'TSTAMPS', 'TRIALS', 'CONDITIONS', 'STIMS', 'ACCS', 'RTS', 'RunDuration');
return

end

%% Helper function to encapsulate the keypad/gamepad presses
% use getKPOnebackReponse when using numeric keypad
% use getGPOnebackResponse when using gamepad
function event=getKPOneBackResponse(event, startrt, trialctr, categories, stims)
kpyes=KbName('1');
%kpyes=KbName({'1!' '2@' '3#' '4$' 'r' 'g' 'b' 'y' '1' '2' '3' '4'});
kbyes=KbName('1!');
%kbyes=KbName({'1!' '2@' '3#' '4$' 'r' 'g' 'b' 'y' '1' '2' '3' '4'});
[~, ~, KeyCode]=KbCheck;
if(KeyCode(kbyes) || KeyCode(kpyes))
    %Log the new button press event, but only if an event has
    %not already been logged
    if(~isfield(event, 'RT'))
        event.RT=round((GetSecs - startrt)*1000);
        try
            %accuracy = 1 if image index and condition for trialctr is the same as it was for previous trialctr
            event.ACC=( (stims(trialctr)==stims(trialctr-1)) && (categories(trialctr)==categories(trialctr-1) ) );
        catch
            event.ACC=0; %An error should be thrown only when S indicates very first stim is same as previous (which is incorrect)
        end
    end
end
end

function event=getGPOneBackResponse(event, startrt, trialctr, categories, stims)
gpyes=1; %gamepad sends a 1 for yes responses
buttonState = Gamepad('GetButton', 1, gpyes); % poll for response on the 'yes' button
if buttonState %yes button pressed
    if(~isfield(event, 'RT'))
        event.RT=round((GetSecs - startrt)*1000);
        try
            %accuracy = 1 if image index and condition for trialctr is the same as it was for previous trialctr
            event.ACC=( (stims(trialctr)==stims(trialctr-1)) && (categories(trialctr)==categories(trialctr-1) ) );
        catch
            event.ACC=0; %An error should be thrown only when S indicates very first stim is same as previous (which is incorrect)
        end
    end
end
end

%When using keypad input, this function listens for nvolumes worth of
%triggers before proceeding
function KPDummyVolumes(nvolumes)
kptrigger=KbName('5');
%kptrigger=KbName({'5%' 't' '5'});
kbtrigger=KbName('5%');
%kbtrigger=KbName({'5%' 't' '5'});
TRCounter=0;
%This counter is assuming that the scanner sends a keyboard trigger (The
%Siemens Tim Trio 3T sends a numeric '5'). This may require modification on the line checking the values in KeyCode.
%Whatever the case, count the number of triggers received from the scanner.
%When the counter reaches end_fixation_vols, terminate
while (TRCounter<nvolumes)
    [~, ~, KeyCode]=KbCheck;
    while (KeyCode(kbtrigger)==0 && KeyCode(kptrigger)==0)
        [~, ~, KeyCode]=KbCheck;
        WaitSecs(0.001);
        if(KeyCode(kbtrigger) || KeyCode(kptrigger))
            TRCounter=TRCounter+1;
        end
    end
end
end

function GPDummyVolumes(nvolumes)
gptrigger=5; %gamepad sends a 4 for a scanner trigger
Gamepad('Unplug');
TRCounter=0;
%count up the number of triggers received until we hit nvolumes
while TRCounter<nvolumes;
    buttonState = Gamepad('GetButton', 1, gptrigger); % the gamepad has 32 channels, no. 5 is the trigger channel
    if buttonState ~=0;
        TRCounter=TRCounter+1;
        WaitSecs(0.05);
    end
end
end
