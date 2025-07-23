function GraspingTask(participant_number, run_number)

%% Debug
p.DEBUG = false;

%% Parameters

% General
p.TR = 1; % in seconds

% Arduino pins and brightness values (1-255)
p.ARDUINO.FIXATION.PIN =     2;
p.ARDUINO.ILLUMINATOR.PIN =  4;
p.ARDUINO.EXPERIMENTOR.PIN = 6;
p.ARDUINO.FIXATION.BRIGHTNESS =     100;
p.ARDUINO.ILLUMINATOR.BRIGHTNESS =  255;
p.ARDUINO.EXPERIMENTOR.BRIGHTNESS = 255;

% Timing (in seconds)
% MUST BE DIVISIBLE BY TR
p.TIMING.BASELINE_INITIAL = 16;
p.TIMING.TASK =              4;
p.TIMING.ITI_SHORT =         8;
p.TIMING.ITI_LONG =         12;
p.TIMING.BASELINE_FINAL =   16;

% Sounds
p.SOUND.VOLUME = 1; % 1 = 100%
p.SOUND.LATENCY = .08; %lower = better timing, too low = loss of audio quality or crash
p.SOUND.CHANNELS = 1;
p.SOUND.DEVICE_ID = 2; %seems to work
p.SOUND.FREQUENCY = 44100;
p.SOUND.FILE_TYPE = ".wav";

% Durations (in seconds)
p.DURATION.AUDIO =       0.5;
p.DURATION.ILLUMINATOR = 0.25;

% Folders
p.FOLDERS.ORDERS = "." + filesep + "Orders" + filesep;
p.FOLDERS.DATA = "." + filesep + "Data" + filesep;
p.FOLDERS.SOUNDS = "." + filesep + "Sounds" + filesep;

% Filepaths
p.FILEPATH.ORDER = sprintf("%sPAR%02d_RUN%02d.csv", p.FOLDERS.ORDERS, participant_number, run_number);
p.FILEPATH.SAVE = sprintf("%sPAR%02d_RUN%02d_%s", p.FOLDERS.DATA, participant_number, run_number, getTimestamp);

% Triggers
p.TRIGGER.TIME_BEFORE_TRIGGER_MUST_START_LOOKING_SEC = 0.010; %should be less than TR
p.TRIGGER.TIME_BEFORE_TRIGGER_CAN_START_LOOKING_SEC =  0.500;
p.TRIGGER.TIME_AFTER_MISSED_TRIGGER_STOP_LOOKING_SEC = 0.005;

% Misc
p.KEYS.TRIGGER_NAMES = ["5%" "t"];
p.KEYS.STOP_NAMES = ["ESCAPE"];

%% Prep

% error if no Psychtoolbox
if ~exist("WaitSecs")
    error("This script requires Psychtoolbox")
end

% warn if debug
if p.DEBUG
    warning("DEBUG MODE IS ENABLED: arduino will not be used")
end

% error if invalid durations
if (p.DURATION.AUDIO + p.DURATION.ILLUMINATOR) > p.TR
    error("Combined duration of audio and illumination should not exceed 1 TR")
end

% error if timing not divisible by TR
for T = string(fields(p.TIMING))'
    if rem(p.TIMING.(T), p.TR)
        error("p.TIMING.%s must be divisible by p.TR", T)
    end
end

% get key ID
KbName('UnifyKeyNames');
p.KEYS.TRIGGER = arrayfun(@(x) KbName(x.char), p.KEYS.TRIGGER_NAMES);
p.KEYS.STOP = arrayfun(@(x) KbName(x.char), p.KEYS.STOP_NAMES);

% precall PTB functions a few times to prevent delays
for i = 1:10
    GetSecs;
    KbCheck;
end

%create data folder if needed
if ~exist(p.FOLDERS.DATA), mkdir(p.FOLDERS.DATA);, end

% load order
d.loaded_order = readtable(p.FILEPATH.ORDER);
d.loaded_order.Condition = string(d.loaded_order.Condition); % convert to char to string

% load and prepare sounds
fprintf("Loading and testing sounds:\n");
InitializePsychSound(1);
PsychPortAudio('Close'); % close any existing audio handles
for cond = unique(d.loaded_order.Condition)'
    % filepath
    fp = p.FOLDERS.SOUNDS + cond + p.SOUND.FILE_TYPE;
    fprintf("  %s\n", fp);

    % exists?
    if ~exist(fp,"file")
        error("Cannot find: %s\n",fp);
    end

    % load
    [snd, freq] = audioread(fp);
    snd = snd(:,1)'; %mono

    % verify freq
    if freq ~= p.SOUND.FREQUENCY
        error("Loaded sound had unexpected encoding frequency")
    end
    
    % open player
    s.(cond) = PsychPortAudio('Open', p.SOUND.DEVICE_ID, 1, [], freq, p.SOUND.CHANNELS, [], p.SOUND.LATENCY);

    % place sound in player
    PsychPortAudio('FillBuffer', s.(cond), snd);

    % set volume
    PsychPortAudio('Volume', s.(cond), p.SOUND.VOLUME);

    %play (faster response later)
    if ~p.DEBUG
        PsychPortAudio('Start', s.(cond));
        PsychPortAudio('Stop', s.(cond), 1);
    end
end

% initialize Arduino
if ~p.DEBUG
    % get or connect
    global ard
    if ~isobject(ard) || ~ard.isvalid
        ard = init_arduino('Mega 2560');
    end

    % turn all lights on
    fprintf("Turning all lights on\n");
    for LED = ["FIXATION" "ILLUMINATOR" "EXPERIMENTOR"]
        ard.analogWrite(p.ARDUINO.(LED).PIN, p.ARDUINO.(LED).BRIGHTNESS);
    end
end

% precalculate key time-in-volumes
time_in_volume_can_accept_trigger =             p.TR - p.TRIGGER.TIME_BEFORE_TRIGGER_CAN_START_LOOKING_SEC;
time_in_volume_must_stop_and_look_for_trigger = p.TR - p.TRIGGER.TIME_BEFORE_TRIGGER_MUST_START_LOOKING_SEC;
time_in_volume_trigger_was_not_received =       p.TR + p.TRIGGER.TIME_AFTER_MISSED_TRIGGER_STOP_LOOKING_SEC;
cue_start = 0; %p.TR - (p.DURATION.AUDIO + p.DURATION.ILLUMINATOR);
time_audio_start = cue_start;
time_audio_end = cue_start + p.DURATION.AUDIO;
time_illum_start = time_audio_end;
time_illum_end = time_illum_start + p.DURATION.ILLUMINATOR;


%% Create volume schedule

% total duration and number of volumes
d.number_trials = size(d.loaded_order, 1);
d.total_duration = p.TIMING.BASELINE_INITIAL + ...                                % initial baseline
                 (p.TIMING.TASK * d.number_trials) + ...                          % task executions
                 (p.TIMING.ITI_SHORT * nnz(~d.loaded_order.HasLongITI)) + ...   % short ITIs
                 (p.TIMING.ITI_LONG * nnz(d.loaded_order.HasLongITI)) + ...     % long ITIs
                 p.TIMING.BASELINE_INITIAL;                                     % final baseline
d.number_volumes = d.total_duration / p.TR;
fprintf("\nRun will be %g seconds = %d volumes (TR = %g)\n", d.total_duration, d.number_volumes, p.TR);

% initialize table
fs = ["Volume"      "double"
      "Trial"       "double"
      "Condition"   "string"
      "Phase"       "string"
      "HasAudio"    "logical"
      "HasIllum"    "logical"
      "HasExpLED"   "logical"
      ];
d.schedule = table('Size', [d.number_volumes size(fs,1)], 'VariableNames', fs(:,1), 'VariableTypes', fs(:,2));
vol = 0;

% initial baseline
for v = 1:(p.TIMING.BASELINE_INITIAL / p.TR)
    vol = vol + 1;
    d.schedule.Volume(vol) = vol;
    d.schedule.Trial(vol) = nan;
    d.schedule.Condition(vol) = "Baseline";
    d.schedule.Phase(vol) = "Initial";
    d.schedule.HasAudio(vol) = false;
    d.schedule.HasIllum(vol) = false;
    d.schedule.HasExpLED(vol) = false;
end

% trials
for trial = 1:d.number_trials
    % task cue and execution
    for v = 1:(p.TIMING.TASK / p.TR)
        vol = vol + 1;
        d.schedule.Volume(vol) = vol;
        d.schedule.Trial(vol) = trial;
        d.schedule.Condition(vol) = d.loaded_order.Condition(trial);
        d.schedule.Phase(vol) = "Execution";
        d.schedule.HasAudio(vol) = v==1;
        d.schedule.HasIllum(vol) = v==1;
        d.schedule.HasExpLED(vol) = false;
    end

    % ITI
    if d.loaded_order.HasLongITI(trial)
        dur = p.TIMING.ITI_LONG;
    else
        dur = p.TIMING.ITI_SHORT;
    end
    for v = 1:(dur / p.TR)
        vol = vol + 1;
        d.schedule.Volume(vol) = vol;
        d.schedule.Trial(vol) = trial;
        d.schedule.Condition(vol) = d.loaded_order.Condition(trial);
        d.schedule.Phase(vol) = "ITI";
        d.schedule.HasAudio(vol) = false;
        d.schedule.HasIllum(vol) = false;
        d.schedule.HasExpLED(vol) = (trial ~= d.number_trials); % on unless final trial's ITI
    end
end

% final baseline
for v = 1:(p.TIMING.BASELINE_FINAL / p.TR)
    vol = vol + 1;
    d.schedule.Volume(vol) = vol;
    d.schedule.Trial(vol) = nan;
    d.schedule.Condition(vol) = "Baseline";
    d.schedule.Phase(vol) = "Final";
    d.schedule.HasAudio(vol) = false;
    d.schedule.HasIllum(vol) = false;
    d.schedule.HasExpLED(vol) = false;
end

% check number of volume added
if vol ~= d.number_volumes
    error("Logic error in per-volume schedule creation, an unexpected number of volumes were defined")
end

% calcualte expected volume onset times
d.schedule.ExpectedOnset(:) = 0 : p.TR : (d.total_duration - p.TR);

%% Initialize
d.volume_data(1:d.number_volumes) = struct( 'time_startActual', nan, ...
                                            'time_start', nan, ...
                                            'time_endActual', nan, ...
                                            'volDuration', nan, ...
                                            'volDurationActual', nan, ...
                                            'recievedTrigger', false, ...
                                            'schedule', [], ...
                                            'audio_start', nan, ...
                                            'audio_end', nan, ...
                                            'illum_start', nan, ...
                                            'illum_end', nan ...
                                            );


% Wait for first trigger
fprintf('\n\n\nWaiting for first trigger (%d volumes)...\n\n\n',d.number_volumes)
while 1
    [keyIsDown, ~, keyCode] = KbCheck(-1); %get key(s)
    if keyIsDown
        if any(keyCode(p.KEYS.TRIGGER))
            break
        elseif any(keyCode(p.KEYS.STOP))
            error('Stop key was pressed.')
        end
    end
end

% turn off illum and exp
if ~p.DEBUG
    for LED = ["ILLUMINATOR" "EXPERIMENTOR"]
        ard.analogWrite(p.ARDUINO.(LED).PIN, 0);
    end
end


%% This is time-zero, start of first volume
d.t0 = GetSecs;
t0 = d.t0; % shortcut

%% Run per-volume events
try
for v = 1:d.number_volumes
    % volume start time actual
    if v==1
        d.volume_data(v).time_startActual = 0;
    else
        d.volume_data(v).time_startActual = GetSecs-t0;
    end

    % volume start time
    if v==1 || d.volume_data(v-1).recievedTrigger %is first vol OR prior vol recieved trigger
        d.volume_data(v).time_start = d.volume_data(v).time_startActual; %use actual time
    else %missed a trigger
        d.volume_data(v).time_start = d.volume_data(v-1).time_start + p.TR; %use expected trigger time
    end

    % start message
    fprintf("\nStarting volume %d/%d at %fsec (actual %fsec):\n",v,d.number_volumes,d.volume_data(v).time_start,d.volume_data(v).time_startActual);

    % store volume events
    d.volume_data(v).schedule = d.schedule(v,:);
    disp(d.volume_data(v).schedule)

    % experimenter LED
    if d.volume_data(v).schedule.HasExpLED
        if ~p.DEBUG
            ard.analogWrite(p.ARDUINO.EXPERIMENTOR.PIN, p.ARDUINO.EXPERIMENTOR.BRIGHTNESS);
        end
        fprintf("-Experimentor LED is on\n");
    else
        if ~p.DEBUG
            ard.analogWrite(p.ARDUINO.EXPERIMENTOR.PIN, 0);
        end
    end

    % save if baseline or ITI AND there is at least 500ms remaining in the volume
    if d.volume_data(v).schedule.Condition=="Baseline" || d.volume_data(v).schedule.Phase=="ITI"
        t = GetSecs - t0;
        t_vol = t - d.volume_data(v).time_start;
        if (p.TR - t_vol) >= 0.5
            fprintf("-Saving\n")
            save(p.FILEPATH.SAVE + "_INCOMPLETE","p","d")
        end
    end

    % audio
    need_audio_start = d.volume_data(v).schedule.HasAudio;
    need_audio_stop = d.volume_data(v).schedule.HasAudio;

    % illum LED
    need_illum_start = d.volume_data(v).schedule.HasIllum;
    need_illum_stop = d.volume_data(v).schedule.HasIllum;

    % volume events
    while 1
        % time
        t = GetSecs - t0;                        % time relative to first volume
        t_vol = t - d.volume_data(v).time_start; % time in volume

        if need_audio_start && (t_vol >= time_audio_start)
            PsychPortAudio('Start', s.(d.volume_data(v).schedule.Condition));
            d.volume_data(v).audio_start = t_vol;
            fprintf("-Audio starting at %g\n", d.volume_data(v).audio_start);
            need_audio_start = false;
        end

        if need_audio_stop && (t_vol >= time_audio_end)
            PsychPortAudio('Stop', s.(d.volume_data(v).schedule.Condition));
            d.volume_data(v).audio_end = t_vol;
            fprintf("-Audio stopped at %g\n", d.volume_data(v).audio_end);
            need_audio_stop = false;
        end

        if need_illum_start && (t_vol >= time_illum_start)
            if ~p.DEBUG
                ard.analogWrite(p.ARDUINO.ILLUMINATOR.PIN, p.ARDUINO.ILLUMINATOR.BRIGHTNESS);
            end
            d.volume_data(v).illum_start = t_vol;
            fprintf("-Illumination starting at %g\n", d.volume_data(v).illum_start);
            need_illum_start = false;
        end

        if need_illum_stop && (t_vol >= time_illum_end)
            if ~p.DEBUG
                ard.analogWrite(p.ARDUINO.ILLUMINATOR.PIN, 0);
            end
            d.volume_data(v).illum_end = t_vol;
            fprintf("-Illumination stopping at %g\n", d.volume_data(v).illum_end);
            need_illum_stop = false;
        end

        % keys
        [keyIsDown, ~, keyCode] = KbCheck(-1);
        if keyIsDown
            if any(keyCode(p.KEYS.TRIGGER)) && (t_vol >= time_in_volume_can_accept_trigger)
                d.volume_data(v).recievedTrigger = true;
                fprintf("~~~~~~~~~~~~~~~~~TRIGGER RECIEVED~~~~~~~~~~~~~~~~~\n")
                break
            elseif any(keyCode(p.KEYS.STOP))
                error('Stop key was pressed.')
            end
        end

        % stop if it's very late in the volume, need to exclusively look for the trigger
        if t_vol >= time_in_volume_must_stop_and_look_for_trigger
            break; 
        end
    end

    % look for trigger if not yet received
    if ~d.volume_data(v).recievedTrigger
        while 1
            %time
            t = GetSecs - t0;
            t_vol = t - d.volume_data(v).time_start;

            %allow illum end during this (necessary due to timing)
            if need_illum_stop && (t_vol >= time_illum_end)
                if ~p.DEBUG
                    ard.analogWrite(p.ARDUINO.ILLUMINATOR.PIN, 0);
                end
                d.volume_data(v).illum_end = t_vol;
                fprintf("-Illumination stopping at %g\n", d.volume_data(v).illum_end);
                need_illum_stop = false;
            end

            %check keys
            [keyIsDown, ~, keyCode] = KbCheck(-1);
            if keyIsDown
                if any(keyCode(p.KEYS.TRIGGER))
                    d.volume_data(v).recievedTrigger = true;
                    fprintf("~~~~~~~~~~~~~~~~~TRIGGER RECIEVED~~~~~~~~~~~~~~~~~\n")
                    break
                elseif any(keyCode(p.KEYS.STOP))
                    error('Stop key was pressed.')
                end
            end

            %stop if we go over time
            if t_vol >= time_in_volume_trigger_was_not_received
                warning("No trigger was recieved. Continuing with expected timing...")
                break; 
            end
        end
    end

    % stop audio/illum if still going
    t = GetSecs - t0;                        % time relative to first volume
    t_vol = t - d.volume_data(v).time_start; % time in volume
    if need_audio_stop
        PsychPortAudio('Stop', s.(d.volume_data(v).schedule.Condition));
        d.volume_data(v).audio_end = t_vol;
        fprintf("-Audio stopped at %g\n", d.volume_data(v).audio_end);
    end
    if need_illum_stop
        if ~p.DEBUG
            ard.analogWrite(p.ARDUINO.ILLUMINATOR.PIN, 0);
        end
        d.volume_data(v).illum_end = t_vol;
        fprintf("-Illumination stopping at %g\n", d.volume_data(v).illum_end);
    end
	
    %end of volume
    d.volume_data(v).time_endActual = GetSecs-t0;
    d.volume_data(v).volDuration = d.volume_data(v).time_endActual - d.volume_data(v).time_start;
    d.volume_data(v).volDurationActual = d.volume_data(v).time_endActual - d.volume_data(v).time_startActual;
    fprintf("-duration: %f seconds\n",d.volume_data(v).volDuration)

end

%% Done

%final save
save(p.FILEPATH.SAVE + "_COMPLETE",'p','d')

% stop and close audio
fprintf("Closing audio devices...\n")
for f = string(fields(s))'
    PsychPortAudio('Stop', s.(f), 1);
    PsychPortAudio('Close', s.(f));
end

%turn off all lights
if ~p.DEBUG
    fprintf("Turning off all lights...\n")
    for LED = ["FIXATION" "ILLUMINATOR" "EXPERIMENTOR"]
        ard.analogWrite(p.ARDUINO.(LED).PIN, 0);
    end
end

disp Done!



%% Catch

catch err
    % save
    save(p.FILEPATH.SAVE + "_ERROR")

    % stop and close audio
    fprintf("Closing audio devices...\n")
    for f = string(fields(s))'
        PsychPortAudio('Stop', s.(f), 1);
        PsychPortAudio('Close', s.(f));
    end
    
    %turn off all lights
    if ~p.DEBUG
        fprintf("Turning off all lights...\n")
        for LED = ["FIXATION" "ILLUMINATOR" "EXPERIMENTOR"]
            ard.analogWrite(p.ARDUINO.(LED).PIN, 0);
        end
    end

    % rethrow the error
    rethrow(err)
end












%% Helper Functions

function [timestamp] = getTimestamp
c = round(clock);
timestamp = sprintf('%d-%d-%d_%d-%d_%d',c([4 5 6 3 2 1]));