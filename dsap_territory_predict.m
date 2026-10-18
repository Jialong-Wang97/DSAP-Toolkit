function [prediction,metadata,folder]=dsap_territory_predict(sequence,metadata,folder,configFile,cancelRequested)
% Run a separate Python process with argument-list quoting (never a shell).
root=fileparts(mfilename('fullpath'));if nargin<4,configFile=fullfile(root,'vascular_segmentation','config.yaml');end
dsap_require_dependency('territory',configFile);
if nargin<5,cancelRequested=@() false;end
assert(~cancelRequested(),'DSAP:TerritoryCancelled','供血区预测已取消。');
if nargin<3||isempty(folder),folder=tempname;end
cfg=jsondecode(fileread(configFile));if ~isfolder(folder),mkdir(folder);end
assert(~isfile(fullfile(folder,'input.mat')),'DSAP:TerritoryOutput','Choose a fresh prediction directory.');
assert(isnumeric(sequence)&&isreal(sequence)&&all(isfinite(sequence),'all'),'DSAP:TerritoryInput','Expected finite numeric DSA sequence.');
sequence=single(sequence);save(fullfile(folder,'input.mat'),'sequence','-v7');
fid=fopen(fullfile(folder,'metadata.json'),'w');assert(fid>=0);fprintf(fid,'%s',jsonencode(metadata));fclose(fid);
python=cfg.python_path;if isempty(python),python=fullfile(root,'.venv_cave','Scripts','python.exe');end
assert(isfile(python),'DSAP:TerritoryPython','Configure a valid python_path.');
cancelFile=fullfile(folder,'cancel.request');
args=java.util.ArrayList;for a={python,fullfile(root,'vascular_segmentation','inference.py'),'--input',fullfile(folder,'input.mat'), ...
 '--metadata',fullfile(folder,'metadata.json'),'--output',folder,'--config',configFile, ...
 '--parent-pid',num2str(feature('getpid')),'--cancel-file',cancelFile},args.add(java.lang.String(a{1}));end
builder=java.lang.ProcessBuilder(args);builder.redirectErrorStream(true);builder.redirectOutput(java.io.File(fullfile(folder,'python.log')));
process=builder.start();guard=onCleanup(@() kill(process,cancelFile));watch=tic; %#ok<NASGU>
while process.isAlive()
 pause(.1);drawnow;dsap_task_control('check');
 assert(~cancelRequested(),'DSAP:TerritoryCancelled','供血区窗口已关闭，预测已取消。');
 assert(toc(watch)<cfg.timeout_seconds,'DSAP:TerritoryTimeout','Territory prediction timed out; see python.log.');
end
logFile=fullfile(folder,'processing_log.json');assert(isfile(logFile),'DSAP:TerritoryProcess','Python failed; see %s',fullfile(folder,'python.log'));
log=jsondecode(fileread(logFile));
if process.exitValue()~=0||~strcmp(log.status,'needs_review')
 message='Prediction failed';if isfield(log,'message'),message=log.message;end
 error('DSAP:TerritoryInference','%s (log: %s)',message,logFile);
end
assert(strcmp(log.source_id,metadata.source_id),'DSAP:TerritorySource','Prediction belongs to another source.');
prediction=load(fullfile(folder,'prediction.mat'));shape=[size(sequence,2) size(sequence,3)];if ismatrix(sequence),shape=size(sequence);end
assert(isequal(size(prediction.ACA_mask),shape)&&isequal(size(prediction.MCA_mask),shape),'DSAP:TerritoryShape','Mask not in native DSAP coordinates.');
prediction.ACA_mask=logical(prediction.ACA_mask);prediction.MCA_mask=logical(prediction.MCA_mask);
metadata.Inference=log;metadata.Transform=jsondecode(fileread(fullfile(folder,'transform.json')));metadata.PredictionFolder=folder;
end
function kill(p,cancelFile)
if ~p.isAlive(),return;end
fid=fopen(cancelFile,'w');if fid>=0,fclose(fid);end
% The Python watchdog also stops a venv child when the launcher is terminated.
for k=1:20,if ~p.isAlive(),return;end;java.lang.Thread.sleep(50);end
if p.isAlive(),p.destroyForcibly();end
end
