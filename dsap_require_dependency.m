function dsap_require_dependency(component,configFile)
% Check external release dependencies before reading input or starting work.
root=fileparts(mfilename('fullpath'));
switch lower(component)
 case 'perfusion'
  files={'modelfree_deconvolution_corrected.m','centered_temporal_gaussian_filter.m','gausswin.m','detect_aif_onset.m'};
 case 'cave'
  files={'scripts/cave_worker.py','scripts/cave_trial.py','.venv_cave/Scripts/pythonw.exe','third_party/CAVE_DSA/unet/temporal_unet_model.py', ...
   'third_party/CAVE_DSA/checkpoints/sequence_av_sigmoid_image512_ConvGRU_logical-star-1097.pt'};
 case 'territory'
  if nargin<2,configFile=fullfile(root,'vascular_segmentation','config.yaml');end
  if ~isfile(configFile),missing(component);end
  files={'vascular_segmentation/inference.py'};
  cfg=jsondecode(fileread(configFile));
  if ~isfield(cfg,'model_path')||isempty(cfg.model_path),missing(component);end
  model=char(cfg.model_path);
  if ~java.io.File(model).isAbsolute(),model=fullfile(fileparts(configFile),model);end
  if ~isfile(model)&&~isfolder(model),missing(component);end
 case 'legacy'
  files={'timeslice_realm_reader/export_cave_current_rois.js','cave_runtime/node.exe','contracts/TIMESlice_Legacy_Orientation_Contract_v1.mat'};
 otherwise
  error('DSAP:DependencyName','Unknown dependency: %s',component);
end
for k=1:numel(files)
 if ~isfile(fullfile(root,files{k})),missing(component);end
end
end
function missing(component)
error('DSAP:MissingDependency', ...
 'Missing external dependency (%s). This source distribution excludes restricted or unverified components. See THIRD_PARTY.md for required files and installation limitations. No substitute algorithm is used.',component);
end
