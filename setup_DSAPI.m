function report=setup_DSAPI
% Non-destructive source setup. No downloads, license acceptance or savepath.
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'src','geometry'),fullfile(root,'AutoAIF'),fullfile(root,'examples'));
report=struct('Checks',struct('Name',{},'Passed',{},'Detail',{}));
add('MATLAB R2024b',strcmp(version('-release'),'2024b'),'Recommended/tested release: R2024b Update 2.');
add('Windows x64',ispc&&strcmp(computer('arch'),'win64'),'Other operating systems have not been validated.');
add('Java',usejava('jvm'),'Use MATLAB with its JVM enabled.');
add('Image Processing Toolbox',~isempty(ver('images'))&&license('test','image_toolbox'), ...
 'Install with the MathWorks installer under your own MATLAB license.');
report.BasicReady=all([report.Checks.Passed]);
components={'perfusion','cave','territory','legacy'};
for k=1:numel(components)
 try,dsap_require_dependency(components{k});ok=true;detail='Required files present; runtime/scientific validation is separate.';
 catch e,ok=false;detail=e.message;end
 add(components{k},ok,detail);
end
vti=fullfile(root,'third_party','vessel_tortuosity_vti');
names={'vessel_tortousity_index.m','arc_length.m','sd_theta.m','mean_distance_measure.m','num_critical_pts.m'};
add('VTI',all(cellfun(@(x) isfile(fullfile(vti,x)),names)), ...
 'Optional. See THIRD_PARTY.md for author, pinned revision, terms and installation path.');
python=fullfile(root,'.venv_cave','Scripts','python.exe');
pythonOK=false;detail='Python 3.12 x64 required for CAVE/territory; expected .venv_cave/Scripts/python.exe. See THIRD_PARTY.md.';
if isfile(python)&&usejava('jvm')
 try
  args=javaArray('java.lang.String',3);args(1)=java.lang.String(python);args(2)=java.lang.String('-c');
  args(3)=java.lang.String('import sys,torch,numpy,scipy,skimage,pydicom,PIL,pylibjpeg; assert sys.version_info[:2]==(3,12); assert torch.__version__.split(''+'')[0]==''2.6.0''');
  builder=java.lang.ProcessBuilder(args);builder.redirectErrorStream(true);p=builder.start();
  guard=onCleanup(@() stop(p));watch=tic;
  while p.isAlive()&&toc(watch)<60,pause(.1);end
  pythonOK=~p.isAlive()&&p.exitValue()==0;
  detail='Python 3.12 / torch 2.6.0 and required package import probe (60-second limit). See THIRD_PARTY.md if FAIL.';
 catch e,detail=e.message;end
end
add('Python packages',pythonOK,detail);
% A file-presence probe does not resolve redistribution rights or adapter availability.
report.FullWorkflowReady=false;
report.Status='NOT READY FOR REVIEWER RELEASE';
fprintf('\nBasic MATLAB setup: %s\n',string(report.BasicReady));
fprintf('Full perfusion reviewer workflow: UNRESOLVED (see REVIEWER_RELEASE_CHECKLIST.md).\n');
fprintf('No external components were downloaded or modified.\n');
 function add(name,passed,detail)
  report.Checks(end+1)=struct('Name',name,'Passed',logical(passed),'Detail',detail);
  state='MISSING / UNRESOLVED';if passed,state='PASS';end
  fprintf('[%s] %s: %s\n',state,name,detail);
 end
end
function stop(p)
if p.isAlive(),p.destroyForcibly();end
end
