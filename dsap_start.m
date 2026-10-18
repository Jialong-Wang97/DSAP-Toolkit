function fig=dsap_start
% Start the original workspace without requiring optional external runtimes.
root=fileparts(mfilename('fullpath'));
addpath(root,fullfile(root,'AutoAIF'),fullfile(root,'src','geometry'));
fig=dsap_workspace;
end
