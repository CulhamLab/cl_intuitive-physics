%% parameters
pin_values = [2 255;
              4 255;
              6 255;
              8 255];

%connect
global ard
if ~isobject(ard) | ~ard.isvalid
    ard = init_arduino('Mega 2560');
end

%turn on specified pin
for i = 1:size(pin_values, 1)
    ard.analogWrite(pin_values(i,1), pin_values(i,2));
end