function report=dsap_environment_check(mode)
% Check current Windows deployment, with no analysis or inference.
% dsap_environment_check       : Native + optional Legacy installation requirements
% dsap_environment_check('native'): Native only; report Legacy gaps without blocking.
if nargin<1,mode='all';end
mode=validatestring(mode,{'all','native'});legacy=strcmp(mode,'all');
root=fileparts(mfilename('fullpath'));
report=struct('ProjectRoot',root,'Mode',mode,'MATLAB',version,'Release',version('-release'), ...
    'Checks',struct('Name',{},'Passed',{},'Required',{},'Detail',{}));
fprintf('DSAP 环境检查（不执行科学分析）\n项目：%s\nMATLAB：%s\n',root,report.MATLAB);
add('Windows x64',ispc&&strcmp(computer('arch'),'win64'),true,computer('arch'));
add('MATLAB release',strcmp(report.Release,'2024b'),true,['要求 R2024b；当前 R' report.Release]);
add('MATLAB JVM',usejava('jvm'),true,'CAVE / Realm 使用 Java ProcessBuilder，SHA 使用 Java。');
image=ver('images');imageReady=~isempty(image)&&license('test','image_toolbox');
functions={'dicominfo','dicomread','niftiread','niftiinfo','medfilt2','poly2mask','imgaussfilt','drawfreehand'};
missing=functions(cellfun(@(name) isempty(which(name)),functions));
add('Image Processing Toolbox',imageReady&&isempty(missing),true, ...
    ['必需；安装与 license 检查。缺少函数：' strjoin(missing,', ')]);
report.InstalledToolboxes=ver;
add('项目 gausswin',strcmpi(which('gausswin'),fullfile(root,'gausswin.m')),true, ...
    '使用项目 gausswin；不要求 Signal Processing Toolbox，须避免其他目录同名函数遮蔽。');

python=fullfile(root,'.venv_cave','Scripts','python.exe');
pythonw=fullfile(root,'.venv_cave','Scripts','pythonw.exe');
probe=fullfile(root,'scripts','dsap_environment_probe.py');
pythonReady=isfile(python)&&isfile(pythonw)&&isfile(probe);detail='';data=struct();
if pythonReady&&usejava('jvm')
    fprintf('检查 Python imports / 版本 / 模型 SHA（不运行 CAVE）…\n');
    try
        [code,output]=run_process({python,probe},60);
        assert(code==0,'DSAP:EnvironmentPython','%s',output);
        data=jsondecode(output);report.Python=data;pythonReady=data.Passed;
        detail=sprintf('%s；base=%s',data.Python,data.BasePrefix);
        if ~data.Passed,detail=[detail newline strjoin(cellstr(string(data.Errors)),newline)];end
    catch e,pythonReady=false;detail=e.message;end
else
    pythonReady=false;detail='缺少 .venv_cave/Scripts/python.exe 或 pythonw.exe。目标机需 Python 3.12 x64 并重建本地 venv。';
end
add('Python / CAVE dependencies',pythonReady,true,detail);
model=fullfile(root,'third_party','CAVE_DSA','checkpoints','sequence_av_sigmoid_image512_ConvGRU_logical-star-1097.pt');
modelReady=isfile(model)&&isfield(data,'Model')&&isfield(data.Model,'Passed')&&data.Model.Passed;
add('CAVE model',modelReady,true,[model '（要求实际权重 SHA 匹配；不接受 Git LFS pointer）']);
resources={'scripts/cave_worker.py','scripts/cave_trial.py','third_party/CAVE_DSA/unet/temporal_unet_model.py'};
missing=resources(~cellfun(@(name) isfile(fullfile(root,name)),resources));
add('CAVE worker / source',isempty(missing),true,['缺少：' strjoin(missing,', ')]);

node=fullfile(root,'cave_runtime','node.exe');reader=fullfile(root,'timeslice_realm_reader');
nodeProbe=fullfile(root,'scripts','dsap_legacy_environment_probe.js');
nodeReady=isfile(node)&&isfile(nodeProbe);detail='缺少 cave_runtime/node.exe 或 scripts/dsap_legacy_environment_probe.js';
if nodeReady&&usejava('jvm')
    try
        [code,output]=run_process({node,nodeProbe},30);
        assert(code==0,'DSAP:EnvironmentRealm','%s',output);report.LegacyRuntime=jsondecode(output);
        nodeReady=report.LegacyRuntime.Loaded&&strcmp(report.LegacyRuntime.Realm,'12.14.2');detail=output;
    catch e,nodeReady=false;detail=e.message;end
end
add('Node / Realm native binding',nodeReady,legacy,detail);
resources={'export_cave_current_rois.js','read_observable_profile.js','nifti_observable_profile.js'};
missing=resources(~cellfun(@(name) isfile(fullfile(reader,name)),resources));
contract=fullfile(root,'contracts','TIMESlice_Legacy_Orientation_Contract_v1.mat');
add('Legacy reader / orientation contract',isempty(missing)&&isfile(contract),legacy, ...
    ['缺少 reader：' strjoin(missing,', ') '；contract：' contract]);
try
    config=dsap_timeslice_paths(root);report.TIMESlice=config;
    add('TIMESlice local database',isfile(config.realmPath)&&isfolder(config.timesliceDbRoot),legacy, ...
        [config.realmPath ' | ' config.timesliceDbRoot]);
catch e,add('TIMESlice local database',false,legacy,e.message);end

shell=fullfile(getenv('SystemRoot'),'System32','WindowsPowerShell','v1.0','powershell.exe');
add('Windows PowerShell launcher',isfile(shell),true,shell);
folders={fullfile(root,'outputs'),fullfile(root,'interactive_results'),tempdir};
for k=1:numel(folders)
    try
        if ~isfolder(folders{k}),[ok,message]=mkdir(folders{k});assert(ok,'%s',message);end
        file=tempname(folders{k});fid=fopen(file,'w');assert(fid~=-1,'目录不可写：%s',folders{k});
        fprintf(fid,'DSAP write probe');fclose(fid);delete(file);
        add('目录可写',true,true,folders{k});
    catch e,add('目录可写',false,true,e.message);end
end
% Default checks include Legacy: calculate Native status separately as well.
isLegacy=startsWith({report.Checks.Name},{'Node','Legacy','TIMESlice'});
report.NativePass=all([report.Checks(~isLegacy).Passed]);
report.LegacyPass=all([report.Checks(isLegacy).Passed])&&report.NativePass;
report.Passed=all([report.Checks([report.Checks.Required]).Passed]);
if report.Passed,fprintf('\nPASS (%s)\n',mode);
else
    fprintf('\nFAIL：\n');bad=report.Checks([report.Checks.Required]&~[report.Checks.Passed]);
    for k=1:numel(bad),fprintf('- %s：%s\n',bad(k).Name,bad(k).Detail);end
end
fprintf('注意：普通 Python venv 不可直接搬迁；pyvenv.cfg 的 base Python 必须在目标机有效。\n');
fprintf('本检查不读取病例，不验证某一 Legacy 序列的 source/orientation，不运行科学 gold / 性能测试。\n');
    function add(name,passed,required,detail)
        report.Checks(end+1)=struct('Name',name,'Passed',logical(passed),'Required',required,'Detail',char(detail));
        status='PASS';if ~passed,status='FAIL';if ~required,status='OPTIONAL MISSING';end,end
        fprintf('[%s] %s：%s\n',status,name,detail);
    end
end
function [code,output]=run_process(args,timeout)
% Exact argument array avoids shell quoting/cwd assumptions.
stdout=tempname;stderr=tempname;files=onCleanup(@() remove_logs(stdout,stderr));
argv=javaArray('java.lang.String',numel(args));
for k=1:numel(args),argv(k)=java.lang.String(args{k});end
builder=java.lang.ProcessBuilder(argv);builder.redirectOutput(java.io.File(stdout));builder.redirectError(java.io.File(stderr));
process=builder.start();cleanup=onCleanup(@() stop_process(process));started=tic;
while process.isAlive()
    if toc(started)>timeout,error('DSAP:EnvironmentTimeout','环境检查子进程超时：%s',args{1});end
    pause(.05);
end
code=process.exitValue();output=strtrim(fileread(stdout));
if code~=0,output=[output newline fileread(stderr)];end
end
function stop_process(process)
if process.isAlive(),process.destroyForcibly();process.waitFor();end
end
function remove_logs(varargin)
for k=1:nargin,if isfile(varargin{k}),delete(varargin{k});end,end
end
