function [data, setup] = fillSetupFromInfoTable_v2(setup, Info, compiled_blocks_path)
%% Info.mat Table is a variable that stores all recording file information

%  Currently, the column order of Info is:
I = 1; %ignore (0 or 1 allowing user to "hide" some files from analysis)
P = 2; %first part of the path
U = 3; %part of the path, not every user will have this, okay to leave empty
M = 4; %part of the path, no underscores
D = 5; %part of the path, YYYY-MM-DD
B = 6; %part of the path - full block name used for BOT
R = 7; %which data to consider as coming from the same ROI, per mouse
IS = 8; %block or BOT numbers
TS = 9; %Tosca session #
TR = 10; %Tosca run #
AP = 11; %part of the path, folder where fall.mats are stored
FR = 12; %15 or 30, eventually we can detect this automatically
RR = 13; %do you have red cells? 0 or 1 %Not used right now
VR = 14; %voltage recording (0 for widefield, 1 for 2p)
VN = 15; %full voltage recording name (if widefield only)
SN = 16; %type of stim presentation in plain text
SP = 17; %stim protocol (number corresponding to stim)

%% Look for files that match stim_protocol
%Later we could update this to also look for other parameters

%stim protocol code is:
%noiseburst=1
%ReceptiveField=2
%FM sweep=3
%SAM = 5
%widefield=4
%SAM freq = 6
code = {'Noiseburst', 'Receptive Field', 'FM sweep', 'SAM', 'Widefield', 'SAM freq'};
display(['Analyzing ' code{setup.stim_protocol} ' files'])

%Remove header from Info
Info(1,:) = [];

%Find table rows that match stim_protocol
stims = [Info{:,SP}]';
matching_stims = stims == setup.stim_protocol;
currentInfo = Info(matching_stims,:);

%Remove rows that are set to "Ignore"
ignore = [currentInfo{:,I}]';
currentInfo = currentInfo(ignore == 0,:);

%% Fill setup and data

%Make data struct with the following format:
%data.([mouseID]).(['ImagingBlock' Imaging_Num]).VARIABLE
%And: data.([mouseID]).parameters

cd(compiled_blocks_path)
data = struct;

%Per each mouse, combine blocks that come from the same ROI
mice = cellstr([currentInfo{:,M}])';
uniqueMice = unique(mice);

for i = 1:length(uniqueMice)
    currentMouse = uniqueMice{i};
    matching_mice = strcmp(currentMouse, mice);
    
    currentInfo_M = currentInfo(matching_mice,:);
    ROIs = [currentInfo_M{:,R}]'; %This requires every block to have an ROI number, which corresponds
    %to which data was run together in Suite2p. If left empty there will be an error
    uniqueROIs = unique(ROIs);
    
    for j = 1:length(uniqueROIs)
        currentROI = uniqueROIs(j);
        currentInfo_R = currentInfo_M(ROIs == currentROI,:); 

        %Fill setup with structure {Mouse, ROI}
        setup.mousename{i,j}         =   currentMouse;
        setup.ROIs{i,j}              =   currentROI;
        setup.expt_date{i,j}         =   [currentInfo_R{:,D}];
        setup.Imaging_sets{i,j}      =   [currentInfo_R{:,IS}];
        setup.Session{i,j}           =   [currentInfo_R{:,TS}];
        setup.Tosca_Runs{i,j}        =   [currentInfo_R{:,TR}];
        

        block_filenames = cell(1,size(currentInfo_R,1));
        unique_block_names = cell(1,size(currentInfo_R,1));
        for r = 1:size(currentInfo_R,1)
            block_filenames{1,r} = strcat('Compiled_', currentMouse, '_', [currentInfo_R{r,D}], ...
            '_Block_', num2str([currentInfo_R{r,IS}]), '_Session_', num2str([currentInfo_R{r,TS}]), ...
            '_Run_', num2str([currentInfo_R{r,TR}]), '_', [currentInfo_R{r,SN}]);
            
            load(block_filenames{1,r})
        
            unique_block_names{1,r} = strcat('Block', num2str([currentInfo_R{r,IS}]),...
                '_Session', num2str([currentInfo_R{r,TS}]), '_Run', num2str([currentInfo_R{r,TR}]));

            data.([currentMouse]).parameters = block.parameters; %This will be written over every time
            %This assumes that the block parameters are the same for every stim paradigm, but they might not be
            %For example if some trials are lost. We'll have to fix this at some point.
            data.([currentMouse]).([unique_block_names{1,r}]) = block;
            clear('block');
        end
        setup.block_filename{i,j} = [block_filenames{:,:}];
        setup.unique_block_names{i,j} = [string(unique_block_names(:,:))];
    end
end

end